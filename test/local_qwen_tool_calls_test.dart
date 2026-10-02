import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:llm_llamacpp/llm_llamacpp.dart';
import 'package:luma/features/chat/providers/local_qwen_client.dart';

void main() {
  group('Qwen3.5 tool calls', () {
    test('parses the XML function form Qwen3.5 writes', () {
      final calls = ToolCallParser.parseToolCalls(
        '<tool_call>\n<function=web_search>\n<parameter=query>\n'
        'weather in Amsterdam today\n</parameter>\n</function>\n</tool_call>',
      );
      expect(calls, hasLength(1));
      expect(calls.single.name, 'web_search');
      expect(jsonDecode(calls.single.arguments), {
        'query': 'weather in Amsterdam today',
      });
    });

    test('keeps multi-line values and reads several parameters', () {
      final calls = ToolCallParser.parseToolCalls(
        'Let me save that.\n<tool_call>\n<function=create_note>\n'
        '<parameter=title>\nGroceries\n</parameter>\n<parameter=content>\n'
        'milk\neggs\n</parameter>\n</function>\n</tool_call>',
      );
      expect(jsonDecode(calls.single.arguments), {
        'title': 'Groceries',
        'content': 'milk\neggs',
      });
    });

    test('accepts a function block with no tool_call wrapper', () {
      final calls = ToolCallParser.parseToolCalls(
        '<function=web_search>\n<parameter=query>\nluma app\n</parameter>\n'
        '</function>',
      );
      expect(calls.single.name, 'web_search');
    });

    test('still parses the Hermes JSON form', () {
      final calls = ToolCallParser.parseToolCalls(
        '<tool_call>\n{"name": "web_search", "arguments": {"query": "x"}}\n'
        '</tool_call>',
      );
      expect(calls.single.name, 'web_search');
      expect(jsonDecode(calls.single.arguments), {'query': 'x'});
    });
  });

  group('LocalQwenClient.coerceArguments', () {
    const schema = {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'days': {'type': 'integer'},
        'paid': {'type': 'number'},
        'all_day': {'type': 'boolean'},
        'ingredients': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    };

    test('turns parameter text into the schema types', () {
      expect(
        LocalQwenClient.coerceArguments(schema, {
          'query': '2026',
          'days': '7',
          'paid': '12.5',
          'all_day': 'True',
          'ingredients': '["rice", "beans"]',
        }),
        {
          'query': '2026',
          'days': 7,
          'paid': 12.5,
          'all_day': true,
          'ingredients': ['rice', 'beans'],
        },
      );
    });

    test('stringifies a number given for a string parameter', () {
      expect(LocalQwenClient.coerceArguments(schema, {'query': 2026}), {
        'query': '2026',
      });
    });

    test('leaves values that do not convert alone', () {
      expect(LocalQwenClient.coerceArguments(schema, {'days': 'soon'}), {
        'days': 'soon',
      });
    });
  });
}
