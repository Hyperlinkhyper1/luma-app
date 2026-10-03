const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

export class CruiseAudio {
  constructor() {
    this.context = null;
    this.master = null;
    this.volume = .55;
    this.muted = false;
    this.nodes = [];
    this.channels = {};
    this.stepTime = 0;
    this.elapsed = 0;
    this.previousFlash = 0;
    this.thunderCooldown = 0;
    this.disposed = false;
  }

  async start() {
    if (this.disposed) return;
    if (this.context) {
      if (this.context.state === 'suspended') await this.context.resume();
      return;
    }
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!AudioContext) return;
    const context = new AudioContext();
    this.context = context;
    this.master = context.createGain();
    this.master.gain.value = this.muted ? 0 : this.volume;
    const limiter = context.createDynamicsCompressor();
    limiter.threshold.value = -15;
    limiter.knee.value = 18;
    limiter.ratio.value = 5;
    limiter.attack.value = .015;
    limiter.release.value = .4;
    this.master.connect(limiter).connect(context.destination);
    this.nodes.push(this.master, limiter);
    this.noise = context.createBuffer(2, context.sampleRate*5, context.sampleRate);
    for (let channel = 0; channel < 2; channel++) {
      const data = this.noise.getChannelData(channel);
      let brown = 0;
      for (let i = 0; i < data.length; i++) {
        brown = (brown + (Math.random()*2-1)*.025)/1.025;
        data[i] = (Math.random()*2-1)*.48 + brown*1.7;
      }
    }
    this.channels.ocean = this.noiseChannel('lowpass', 580, .17);
    this.channels.wind = this.noiseChannel('bandpass', 340, .03, .55);
    this.channels.rain = this.noiseChannel('highpass', 1300, 0);
    this.channels.hiss = this.noiseChannel('bandpass', 3500, .015, .32);
    this.channels.engine = this.tonalChannel(43, .02, 'sine');
    this.channels.engineHarmonic = this.tonalChannel(86.2, .006, 'sine');
    this.channels.tender = this.tonalChannel(73, 0, 'triangle');
    await context.resume();
  }

  noiseChannel(type, frequency, level, q = .7) {
    const source = this.context.createBufferSource();
    source.buffer = this.noise;
    source.loop = true;
    const filter = this.context.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = frequency;
    filter.Q.value = q;
    const gain = this.context.createGain();
    gain.gain.value = level;
    source.connect(filter).connect(gain).connect(this.master);
    source.start(0, Math.random()*4);
    this.nodes.push(source,filter,gain);
    return { source, filter, gain };
  }

  tonalChannel(frequency, level, type) {
    const source = this.context.createOscillator();
    const gain = this.context.createGain();
    source.type = type;
    source.frequency.value = frequency;
    gain.gain.value = level;
    source.connect(gain).connect(this.master);
    source.start();
    this.nodes.push(source,gain);
    return { source, gain };
  }

  update(dt, { mode = 'walk', speed = 0, night = 0, wet = 0, storm = 0, flash = 0 } = {}) {
    if (!this.context || this.context.state !== 'running' || this.disposed) return;
    dt = clamp(dt,0,.1);
    this.elapsed += dt;
    this.thunderCooldown -= dt;
    const now = this.context.currentTime;
    const seaLevel = mode === 'tender';
    const gust = .7+.18*Math.sin(this.elapsed*.37)+.12*Math.sin(this.elapsed*.91);
    const swell = .78+.22*Math.sin(this.elapsed*.58);
    const target = (channel, value, time = .7) => channel.gain.gain.setTargetAtTime(value,now,time);
    target(this.channels.ocean, (.13+storm*.15)*(seaLevel ? 1.5 : 1)*swell);
    target(this.channels.wind, (.018+storm*.23+wet*.03)*gust);
    target(this.channels.rain, wet*(.045+storm*.08));
    target(this.channels.hiss, .009+wet*.025+storm*.035);
    target(this.channels.engine, seaLevel ? .012 : .026+night*.004);
    target(this.channels.engineHarmonic, seaLevel ? .003 : .009);
    target(this.channels.tender, seaLevel ? .018+clamp(speed,0,12)*.002 : 0);
    this.channels.tender.source.frequency.setTargetAtTime(65+clamp(speed,0,12)*6,now,.3);
    this.channels.wind.filter.frequency.setTargetAtTime(260+storm*480+gust*100,now,1);
    this.channels.ocean.filter.frequency.setTargetAtTime((seaLevel ? 900 : 470)+storm*340,now,1);
    if ((mode === 'walk' || mode === 'walking') && speed > .25) {
      this.stepTime += dt;
      const interval = clamp(.94/Math.max(speed,.5),.23,.62);
      if (this.stepTime >= interval) {
        this.stepTime %= interval;
        this.footstep(wet,speed);
      }
    } else this.stepTime = .2;
    if (flash > .35 && this.previousFlash <= .35 && this.thunderCooldown <= 0) {
      this.thunder(.7+Math.random()*2.7,storm);
      this.thunderCooldown = 4;
    }
    this.previousFlash = flash;
  }

  footstep(wet, speed) {
    const context = this.context, now = context.currentTime;
    const source = context.createBufferSource();
    source.buffer = this.noise;
    const filter = context.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 260+Math.random()*110+wet*600;
    const gain = context.createGain();
    gain.gain.setValueAtTime(0,now);
    gain.gain.linearRampToValueAtTime(.11+Math.min(speed,5)*.008,now+.009);
    gain.gain.exponentialRampToValueAtTime(.0001,now+.13+wet*.04);
    source.connect(filter).connect(gain).connect(this.master);
    source.start(now,Math.random()*4,.2);
    source.onended = () => { source.disconnect(); filter.disconnect(); gain.disconnect(); };
  }

  thunder(delay, storm) {
    const context = this.context, start = context.currentTime+delay;
    const source = context.createBufferSource();
    source.buffer = this.noise;
    source.loop = true;
    const filter = context.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(760,start);
    filter.frequency.exponentialRampToValueAtTime(85,start+5.5);
    const gain = context.createGain();
    gain.gain.setValueAtTime(0,context.currentTime);
    gain.gain.setValueAtTime(.0001,start);
    gain.gain.exponentialRampToValueAtTime(.36+storm*.22,start+.1);
    gain.gain.exponentialRampToValueAtTime(.2,start+.8);
    gain.gain.exponentialRampToValueAtTime(.29,start+1.2);
    gain.gain.exponentialRampToValueAtTime(.0001,start+6.8);
    source.connect(filter).connect(gain).connect(this.master);
    source.start(start,Math.random()*3);
    source.stop(start+7);
    source.onended = () => { source.disconnect(); filter.disconnect(); gain.disconnect(); };
  }

  setVolume(value) {
    this.volume = clamp(Number(value)||0,0,1);
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : this.volume,this.context.currentTime,.08);
  }

  setMuted(value) {
    this.muted = Boolean(value);
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : this.volume,this.context.currentTime,.08);
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    for (const node of this.nodes) {
      if (typeof node.stop === 'function') {
        try { node.stop(); } catch {}
      }
      node.disconnect();
    }
    this.context?.close();
    this.nodes.length = 0;
  }
}
