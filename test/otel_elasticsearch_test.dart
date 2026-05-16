// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_elasticsearch/otel_elasticsearch.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_elasticsearch-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('search records CLIENT span', () async {
    await tracedElasticsearchSearch<String>(
      index: 'logs-2026',
      cluster: 'prod',
      size: 50,
      invoke: () async => const ElasticsearchSearchResult(
        value: 'rows',
        totalHits: 105,
        tookMs: 4,
      ),
    );
    final span = spans.findSpanByName('es search logs-2026');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.client);
    final a = attrsOf(span);
    expect(a['db.system'], 'elasticsearch');
    expect(a['db.collection.name'], 'logs-2026');
    expect(a['elasticsearch.cluster.name'], 'prod');
    expect(a['elasticsearch.size'], 50);
    expect(a['elasticsearch.hits.total'], 105);
    expect(a['elasticsearch.took_ms'], 4);
  });

  test('bulk records items + sets Error when hasErrors', () async {
    await tracedElasticsearchBulk<String>(
      index: 'logs-2026',
      invoke: () async => const ElasticsearchBulkResult(
        value: 'ok',
        itemCount: 100,
        hasErrors: true,
        tookMs: 9,
      ),
    );
    final span = spans.findSpanByName('es bulk logs-2026');
    expect(span!.status, SpanStatusCode.Error);
    final a = attrsOf(span);
    expect(a['elasticsearch.bulk.items'], 100);
    expect(a['elasticsearch.took_ms'], 9);
  });

  test('records exception', () async {
    await expectLater(
      tracedElasticsearchSearch<String>(
        index: 'i',
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(spans.findSpanByName('es search i')!.status, SpanStatusCode.Error);
  });

  test('suppression skips spans', () async {
    await runWithoutElasticsearchInstrumentationAsync(() async {
      await tracedElasticsearchSearch<String>(
        index: 'i',
        invoke: () async => const ElasticsearchSearchResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('es '), isEmpty);
  });
}
