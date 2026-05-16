// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_elasticsearch_suppression.dart';

const _tracerName = 'dartastic_otel_libs_elasticsearch';
const _systemValue = 'elasticsearch';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedElasticsearchSearch` callback.
class ElasticsearchSearchResult<T> {
  const ElasticsearchSearchResult({
    required this.value,
    this.totalHits,
    this.tookMs,
  });
  final T value;
  final int? totalHits;
  final int? tookMs;
}

/// Wraps an Elasticsearch `_search` query in a CLIENT span.
Future<T> tracedElasticsearchSearch<T>({
  required String index,
  required Future<ElasticsearchSearchResult<T>> Function() invoke,
  String? cluster,
  int? size,
}) async {
  if (elasticsearchInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'search',
    'db.collection.name': index,
    'elasticsearch.index': index,
  };
  if (cluster != null) m['elasticsearch.cluster.name'] = cluster;
  if (size != null) m['elasticsearch.size'] = size;

  final span = _tracer().startSpan(
    'es search $index',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.totalHits != null) {
      extras.add(OTel.attributeInt('elasticsearch.hits.total', r.totalHits!));
    }
    if (r.tookMs != null) {
      extras.add(OTel.attributeInt('elasticsearch.took_ms', r.tookMs!));
    }
    if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Pair returned from `tracedElasticsearchBulk` callback.
class ElasticsearchBulkResult<T> {
  const ElasticsearchBulkResult({
    required this.value,
    this.itemCount,
    this.hasErrors,
    this.tookMs,
  });
  final T value;
  final int? itemCount;
  final bool? hasErrors;
  final int? tookMs;
}

/// Wraps an Elasticsearch `_bulk` request in a CLIENT span. Marks
/// span Error when [hasErrors] is true.
Future<T> tracedElasticsearchBulk<T>({
  required String index,
  required Future<ElasticsearchBulkResult<T>> Function() invoke,
  String? cluster,
}) async {
  if (elasticsearchInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'bulk',
    'db.collection.name': index,
    'elasticsearch.index': index,
  };
  if (cluster != null) m['elasticsearch.cluster.name'] = cluster;

  final span = _tracer().startSpan(
    'es bulk $index',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.itemCount != null) {
      extras.add(OTel.attributeInt('elasticsearch.bulk.items', r.itemCount!));
    }
    if (r.tookMs != null) {
      extras.add(OTel.attributeInt('elasticsearch.took_ms', r.tookMs!));
    }
    if (r.hasErrors == true) {
      span.setStatus(SpanStatusCode.Error, 'bulk response has errors');
    }
    if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
