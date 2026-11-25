package main

import (
	"bufio"
	"compress/bzip2"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"strings"

	dem "github.com/markus-wa/demoinfocs-golang/v5/pkg/demoinfocs"
	"github.com/markus-wa/demoinfocs-golang/v5/pkg/demoinfocs/common"
	"github.com/markus-wa/demoinfocs-golang/v5/pkg/demoinfocs/events"
	"github.com/markus-wa/demoinfocs-golang/v5/pkg/demoinfocs/msg"
)

type result struct {
	Map    string   `json:"map"`
	Blocks []string `json:"blocks"`
	Digest string   `json:"digest"`
}

func main() {
	if len(os.Args) != 2 {
		os.Exit(2)
	}
	if err := run(os.Args[1]); err != nil {
		os.Exit(1)
	}
}

func run(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	buffer := bufio.NewReader(file)
	var reader io.Reader = buffer
	if magic, _ := buffer.Peek(3); string(magic) == "BZh" {
		reader = bzip2.NewReader(buffer)
	}
	limited := &io.LimitedReader{R: reader, N: 768 * 1024 * 1024}
	hash := sha256.New()
	demoReader := bufio.NewReader(io.TeeReader(limited, hash))
	magic, err := demoReader.Peek(8)
	if err != nil || string(magic) != "PBDEMS2\x00" {
		return errors.New("expected a CS2 demo")
	}
	info, err := parse(demoReader)
	if err != nil {
		return err
	}
	if _, err := io.Copy(io.Discard, demoReader); err != nil || limited.N == 0 {
		return errors.New("invalid or oversized demo")
	}
	info.Digest = hex.EncodeToString(hash.Sum(nil))
	return json.NewEncoder(os.Stdout).Encode(info)
}

func parse(reader io.Reader) (result, error) {
	config := dem.DefaultParserConfig
	config.MsgQueueBufferSize = 512
	parser := dem.NewParserWithConfig(reader, config)
	defer parser.Close()

	var data result
	var block strings.Builder
	var active bool
	var split bool
	var rounds int
	var attempt byte
	var plant byte

	finishBlock := func() {
		if block.Len() > 0 {
			data.Blocks = append(data.Blocks, block.String())
			block.Reset()
		}
	}
	parser.RegisterNetMessageHandler(func(e *msg.CDemoFileHeader) {
		data.Map = e.GetMapName()
	})
	parser.RegisterNetMessageHandler(func(e *msg.CSVCMsg_ServerInfo) {
		if data.Map == "" {
			data.Map = e.GetMapName()
		}
	})
	parser.RegisterEventHandler(func(events.RoundStart) {
		active = true
		attempt = 0
		plant = 0
	})
	parser.RegisterEventHandler(func(events.TeamSideSwitch) { split = true })
	parser.RegisterEventHandler(func(events.MatchStart) { split = true })
	parser.RegisterEventHandler(func(e events.BombPlantBegin) {
		attempt = site(e.Site)
	})
	parser.RegisterEventHandler(func(e events.BombPlanted) {
		plant = site(e.Site)
	})
	parser.RegisterEventHandler(func(e events.RoundEnd) {
		game := parser.GameState()
		if !active || game.IsWarmupPeriod() || !game.IsMatchStarted() {
			return
		}
		active = false
		if e.Winner != common.TeamTerrorists && e.Winner != common.TeamCounterTerrorists {
			split = true
			return
		}
		if split {
			finishBlock()
			split = false
		}
		outcome := plant
		if outcome == 0 {
			outcome = attempt
		}
		if outcome == 0 {
			outcome = 'o'
		}
		block.WriteByte(outcome)
		rounds++
		if rounds > 500 {
			parser.Cancel()
		}
	})
	if err := parser.ParseToEnd(); err != nil {
		return result{}, err
	}
	finishBlock()
	if rounds == 0 || rounds > 500 || data.Map == "" {
		return result{}, errors.New("no supported rounds")
	}
	return data, nil
}

func site(value events.Bombsite) byte {
	switch value {
	case events.BombsiteA:
		return 'a'
	case events.BombsiteB:
		return 'b'
	default:
		return 0
	}
}
