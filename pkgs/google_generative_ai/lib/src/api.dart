// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'content.dart';
import 'error.dart';
import 'function_calling.dart' show Schema;
import 'model.dart';

final class CountTokensResponse {
  /// The number of tokens that the `model` tokenizes the `prompt` into.
  ///
  /// Always non-negative.
  final int totalTokens;

  /// Optional extra fields in the Vertex AI data model.
  final Map<String, Object?>? _extraFields;

  CountTokensResponse(this.totalTokens) : _extraFields = null;
  CountTokensResponse._(this.totalTokens, this._extraFields);
}

/// Returns the fields other than `totalTokens` that were parsed from JSON for
/// [response].
Map<String, Object?>? countTokensResponseFields(CountTokensResponse response) =>
    response._extraFields;

/// Returns a [CountTokensResponse] as if it was parsed from a JSON map with
/// [extraFields] alongside the total tokends field.
CountTokensResponse createCountTokensResponse(
        int totalTokens, Map<String, Object>? extraFields) =>
    CountTokensResponse._(totalTokens, extraFields);

/// Response from the model; supports multiple candidates.
final class GenerateContentResponse {
  /// Candidate responses from the model.
  final List<Candidate> candidates;

  /// Returns the prompt's feedback related to the content filters.
  final PromptFeedback? promptFeedback;

  final UsageMetadata? usageMetadata;

  // TODO(natebosch): Change `promptFeedback` to a named argument.
  GenerateContentResponse(
    this.candidates,
    this.promptFeedback, {
    this.usageMetadata,
  });

  /// The text content of the text parts of the first of [candidates], if any.
  ///
  /// If the prompt was blocked, or the first candidate was finished for a reason
  /// of [FinishReason.recitation] or [FinishReason.safety], accessing this text
  /// will throw a [GenerativeAIException].
  ///
  /// If the first candidate's content contains any text parts, this value is
  /// the concatenation of the text.
  ///
  /// If there are no candidates, or if the first candidate does not contain any
  /// text parts, this value is `null`.
  ///
  /// If there is more than one candidate, all but the first are ignored. See
  /// [Candidate.text] to get the text content of candidates other than the
  /// first.
  String? get text => switch (candidates) {
        [] => switch (promptFeedback) {
            PromptFeedback(
              :final blockReason,
              :final blockReasonMessage,
            ) =>
              // TODO: Add a specific subtype for this exception?
              throw GenerativeAIException('Response was blocked'
                  '${blockReason != null ? ' due to $blockReason' : ''}'
                  '${blockReasonMessage != null ? ': $blockReasonMessage' : ''}'),
            _ => null,
          },
        [final candidate, ...] => candidate.text,
      };

  /// The inline data parts of the first candidate in [candidates], if any.
  ///
  /// Returns an empty list if there are no candidates, or if the first
  /// candidate has no [DataPart] parts. There is no error thrown if the
  /// prompt or response were blocked.
  Iterable<DataPart> get inlineDatas =>
      candidates.firstOrNull?.content.parts.whereType<DataPart>() ?? const [];

  /// The function call parts of the first candidate in [candidates], if any.
  ///
  /// Returns an empty list if there are no candidates, or if the first
  /// candidate has no [FunctionCall] parts. There is no error thrown if the
  /// prompt or response were blocked.
  Iterable<FunctionCall> get functionCalls =>
      candidates.firstOrNull?.content.parts.whereType<FunctionCall>() ??
      const [];
}

final class EmbedContentResponse {
  /// The embedding generated from the input content.
  final ContentEmbedding embedding;

  EmbedContentResponse(this.embedding);
}

final class BatchEmbedContentsResponse {
  /// The embeddings generated from the input content for each request, in the
  /// same order as provided in the batch request.
  final List<ContentEmbedding> embeddings;

  BatchEmbedContentsResponse(this.embeddings);
}

final class EmbedContentRequest {
  final Content content;
  final TaskType? taskType;
  final String? title;
  final String? model;
  final int? outputDimensionality;

  EmbedContentRequest(this.content,
      {this.taskType, this.title, this.model, this.outputDimensionality});

  Object toJson({String? defaultModel}) => {
        'content': content.toJson(),
        if (taskType case final taskType?) 'taskType': taskType.toJson(),
        if (title != null) 'title': title,
        if (model ?? defaultModel case final model?) 'model': model,
        if (outputDimensionality != null)
          'outputDimensionality': outputDimensionality,
      };
}

/// An embedding, as defined by a list of values.
final class ContentEmbedding {
  /// The embedding values.
  final List<double> values;

  ContentEmbedding(this.values);
}

/// Feedback metadata of a prompt specified in a [GenerativeModel] request.
final class PromptFeedback {
  /// If set, the prompt was blocked and no candidates are returned.
  ///
  /// Rephrase your prompt.
  final BlockReason? blockReason;

  final String? blockReasonMessage;

  /// Ratings for safety of the prompt.
  ///
  /// There is at most one rating per category.
  final List<SafetyRating> safetyRatings;

  PromptFeedback(this.blockReason, this.blockReasonMessage, this.safetyRatings);
}

/// Metadata on the generation request's token usage.
final class UsageMetadata {
  /// Number of tokens in the prompt.
  final int? promptTokenCount;

  /// Total number of tokens across the generated candidates.
  final int? candidatesTokenCount;

  /// Total token count for the generation request (prompt + candidates).
  final int? totalTokenCount;

  /// number for tokens use thinking.
  final int? thoughtsTokenCount;

  UsageMetadata({
    this.promptTokenCount,
    this.candidatesTokenCount,
    this.totalTokenCount,
    this.thoughtsTokenCount,
  });
}

/// Response candidate generated from a [GenerativeModel].
final class Candidate {
  /// Generated content returned from the model.
  final Content content;

  /// List of ratings for the safety of a response candidate.
  ///
  /// There is at most one rating per category.
  final List<SafetyRating>? safetyRatings;

  /// Citation information for model-generated candidate.
  ///
  /// This field may be populated with recitation information for any text
  /// included in the [content]. These are passages that are "recited" from
  /// copyrighted material in the foundational LLM's training data.
  final CitationMetadata? citationMetadata;

  /// The reason why the model stopped generating tokens.
  ///
  /// If empty, the model has not stopped generating the tokens.
  final FinishReason? finishReason;

  final String? finishMessage;

  // TODO: token count?
  Candidate(this.content, this.safetyRatings, this.citationMetadata,
      this.finishReason, this.finishMessage);

  /// The concatenation of the text parts of [content], if any.
  ///
  /// If this candidate was finished for a reason of [FinishReason.recitation]
  /// or [FinishReason.safety], accessing this text will throw a
  /// [GenerativeAIException].
  ///
  /// If [content] contains any text parts, this value is the concatenation of
  /// the text.
  ///
  /// If [content] does not contain any text parts, this value is `null`.
  String? get text {
    if (finishReason case FinishReason.recitation || FinishReason.safety) {
      final String suffix;
      if (finishMessage case final message? when message.isNotEmpty) {
        suffix = ': $message';
      } else {
        suffix = '';
      }
      throw GenerativeAIException(
          'Candidate was blocked due to $finishReason$suffix');
    }
    return switch (content.parts) {
      // Special case for a single TextPart to avoid iterable chain.
      [TextPart(:final text)] => text,
      final parts when parts.any((p) => p is TextPart) =>
        parts.whereType<TextPart>().map((p) => p.text).join(''),
      _ => null,
    };
  }
}

/// Safety rating for a piece of content.
///
/// The safety rating contains the category of harm and the harm probability
/// level in that category for a piece of content. Content is classified for
/// safety across a number of harm categories and the probability of the harm
/// classification is included here.
final class SafetyRating {
  /// The category for this rating.
  final HarmCategory category;

  /// The probability of harm for this content.
  final HarmProbability probability;

  SafetyRating(this.category, this.probability);
}

/// The reason why a prompt was blocked.
enum BlockReason {
  /// Default value to use when a blocking reason isn't set.
  ///
  /// Never used as the reason for blocking a prompt.
  unspecified,

  /// Prompt was blocked due to safety reasons.
  ///
  /// You can inspect `safetyRatings` to see which safety category blocked the
  /// prompt.
  safety,

  /// Prompt was blocked due to other unspecified reasons.
  other;

  static BlockReason _parseValue(String jsonObject) => switch (jsonObject) {
        'BLOCK_REASON_UNSPECIFIED' => BlockReason.unspecified,
        'SAFETY' => BlockReason.safety,
        'OTHER' => BlockReason.other,
        _ => throw unhandledFormat('BlockReason', jsonObject),
      };

  @override
  String toString() => name;
}

/// The category of a rating.
///
/// These categories cover various kinds of harms that developers may wish to
/// adjust.
///
/// Some categories from the rest API are excluded because they are not used by
/// the Gemini generative models.
enum HarmCategory {
  unspecified,

  /// Malicious, intimidating, bullying, or abusive comments targeting another
  /// individual.
  harassment,

  /// Negative or harmful comments targeting identity and/or protected
  /// attributes.
  hateSpeech,

  /// Contains references to sexual acts or other lewd content.
  sexuallyExplicit,

  /// Promotes or enables access to harmful goods, services, and activities.
  dangerousContent;

  static HarmCategory _parseValue(Object jsonObject) => switch (jsonObject) {
        'HARM_CATEGORY_UNSPECIFIED' => unspecified,
        'HARM_CATEGORY_HARASSMENT' => harassment,
        'HARM_CATEGORY_HATE_SPEECH' => hateSpeech,
        'HARM_CATEGORY_SEXUALLY_EXPLICIT' => sexuallyExplicit,
        'HARM_CATEGORY_DANGEROUS_CONTENT' => dangerousContent,
        _ => throw unhandledFormat('HarmCategory', jsonObject),
      };

  String toJson() => switch (this) {
        unspecified => 'HARM_CATEGORY_UNSPECIFIED',
        harassment => 'HARM_CATEGORY_HARASSMENT',
        hateSpeech => 'HARM_CATEGORY_HATE_SPEECH',
        sexuallyExplicit => 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
        dangerousContent => 'HARM_CATEGORY_DANGEROUS_CONTENT'
      };
}

/// The probability that a piece of content is harmful.
///
/// The classification system gives the probability of the content being unsafe.
/// This does not indicate the severity of harm for a piece of content.
enum HarmProbability {
  /// Probability is unspecified.
  unspecified,

  /// Content has a negligible probability of being unsafe.
  negligible,

  /// Content has a low probability of being unsafe.
  low,

  /// Content has a medium probability of being unsafe.
  medium,

  /// Content has a high probability of being unsafe.
  high;

  static HarmProbability _parseValue(Object jsonObject) => switch (jsonObject) {
        'UNSPECIFIED' => HarmProbability.unspecified,
        'NEGLIGIBLE' => HarmProbability.negligible,
        'LOW' => HarmProbability.low,
        'MEDIUM' => HarmProbability.medium,
        'HIGH' => HarmProbability.high,
        _ => throw unhandledFormat('HarmProbability', jsonObject),
      };
}

/// Source attributions for a piece of content.
final class CitationMetadata {
  /// Citations to sources for a specific response.
  final List<CitationSource> citationSources;

  CitationMetadata(this.citationSources);
}

/// Citation to a source for a portion of a specific response.
final class CitationSource {
  /// Start of segment of the response that is attributed to this source.
  ///
  /// Index indicates the start of the segment, measured in bytes.
  final int? startIndex;

  /// End of the attributed segment, exclusive.
  final int? endIndex;

  /// URI that is attributed as a source for a portion of the text.
  final Uri? uri;

  /// License for the GitHub project that is attributed as a source for segment.
  ///
  /// License info is required for code citations.
  final String? license;

  CitationSource(this.startIndex, this.endIndex, this.uri, this.license);
}

/// Reason why a model stopped generating tokens.
enum FinishReason {
  /// Default value to use when a finish reason isn't set.
  ///
  /// Never used as the reason for finshing.
  unspecified,

  /// Natural stop point of the model or provided stop sequence.
  stop,

  /// The maximum number of tokens as specified in the request was reached.
  maxTokens,

  /// The candidate content was flagged for safety reasons.
  safety,

  /// The candidate content was flagged for recitation reasons.
  recitation,

  /// Unknown reason.
  other;

  static FinishReason _parseValue(Object jsonObject) => switch (jsonObject) {
        'UNSPECIFIED' => FinishReason.unspecified,
        'STOP' => FinishReason.stop,
        'MAX_TOKENS' => FinishReason.maxTokens,
        'SAFETY' => FinishReason.safety,
        'RECITATION' => FinishReason.recitation,
        'OTHER' => FinishReason.other,
        _ => throw unhandledFormat('FinishReason', jsonObject),
      };

  @override
  String toString() => name;
}

/// Safety setting, affecting the safety-blocking behavior.
///
/// Passing a safety setting for a category changes the allowed probability that
/// content is blocked.
final class SafetySetting {
  /// The category for this setting.
  final HarmCategory category;

  /// Controls the probability threshold at which harm is blocked.
  final HarmBlockThreshold threshold;

  SafetySetting(this.category, this.threshold);

  Object toJson() =>
      {'category': category.toJson(), 'threshold': threshold.toJson()};
}

/// Probability of harm which causes content to be blocked.
///
/// When provided in [SafetySetting.threshold], a predicted harm probability at
/// or above this level will block content from being returned.
enum HarmBlockThreshold {
  /// Threshold is unspecified, block using default threshold.
  unspecified,

  /// Block when medium or high probability of unsafe content.
  low,

  /// Block when medium or high probability of unsafe content.
  medium,

  /// Block when high probability of unsafe content.
  high,

  /// Always show regardless of probability of unsafe content.
  none;

  String toJson() => switch (this) {
        unspecified => 'HARM_BLOCK_THRESHOLD_UNSPECIFIED',
        low => 'BLOCK_LOW_AND_ABOVE',
        medium => 'BLOCK_MEDIUM_AND_ABOVE',
        high => 'BLOCK_ONLY_HIGH',
        none => 'BLOCK_NONE'
      };
}

/// Configuration options for model generation and outputs.
final class GenerationConfig {
  /// Number of generated responses to return.
  ///
  /// This value must be between [1, 8], inclusive. If unset, this will default
  /// to 1.
  final int? candidateCount;

  /// The set of character sequences (up to 5) that will stop output generation.
  ///
  /// If specified, the API will stop at the first appearance of a stop
  /// sequence. The stop sequence will not be included as part of the response.
  final List<String> stopSequences;

  /// The maximum number of tokens to include in a candidate.
  ///
  /// If unset, this will default to output_token_limit specified in the `Model`
  /// specification.
  final int? maxOutputTokens;

  /// Controls the randomness of the output.
  ///
  /// Note: The default value varies by model.
  ///
  /// Values can range from `[0.0, infinity]`, inclusive. A value temperature
  /// must be greater than 0.0.
  final double? temperature;

  /// The maximum cumulative probability of tokens to consider when sampling.
  ///
  /// The model uses combined Top-k and nucleus sampling. Tokens are sorted
  /// based on their assigned probabilities so that only the most likely tokens
  /// are considered. Top-k sampling directly limits the maximum number of
  /// tokens to consider, while Nucleus sampling limits number of tokens based
  /// on the cumulative probability.
  ///
  /// Note: The default value varies by model.
  final double? topP;

  /// The maximum number of tokens to consider when sampling.
  ///
  /// The model uses combined Top-k and nucleus sampling. Top-k sampling
  /// considers the set of `top_k` most probable tokens. Defaults to 40.
  ///
  /// Note: The default value varies by model.
  final int? topK;

  /// Output response mimetype of the generated candidate text.
  ///
  /// Supported mimetype:
  /// - `text/plain`: (default) Text output.
  /// - `application/json`: JSON response in the candidates.
  final String? responseMimeType;

  /// Output response schema of the generated candidate text.
  ///
  /// - Note: This only applies when the specified ``responseMIMEType`` supports
  ///   a schema; currently this is limited to `application/json`.
  final Schema? responseSchema;

  /// The modalities that should be included in the response.
  ///
  /// Supported values:
  /// - `text`: Text output.
  /// - `image`: Image output.
  final List<String>? responseModalities;

  /// The thinkingBudget parameter guides the model on the number of thinking tokens to use when generating a response.
  ///
  /// disable thinking by setting thinkingBudget to 0. Setting the thinkingBudget to -1 turns on dynamic thinking.
  ///
  /// Note: only supported in Gemini 2.5 Flash (Range:128~32768), 2.5 Pro(Range:0~24576), and 2.5 Flash-Lite(Range:512~24576).
  // final int? thinkingBudget;
  // final bool? includeThoughts;
  final Map<String, dynamic>? thinkingConfig;

  GenerationConfig({
    this.candidateCount,
    this.stopSequences = const [],
    this.maxOutputTokens,
    this.temperature,
    this.topP,
    this.topK,
    this.responseMimeType,
    this.responseSchema,
    this.responseModalities,
    this.thinkingConfig,
  });

  Map<String, Object?> toJson() => {
        if (candidateCount case final candidateCount?)
          'candidateCount': candidateCount,
        if (stopSequences.isNotEmpty) 'stopSequences': stopSequences,
        if (maxOutputTokens case final maxOutputTokens?)
          'maxOutputTokens': maxOutputTokens,
        if (temperature case final temperature?) 'temperature': temperature,
        if (topP case final topP?) 'topP': topP,
        if (topK case final topK?) 'topK': topK,
        if (responseMimeType case final responseMimeType?)
          'responseMimeType': responseMimeType,
        if (responseSchema case final responseSchema?)
          'responseSchema': responseSchema,
        if (responseModalities case final responseModalities?)
          'responseModalities': responseModalities,
        if (thinkingConfig case final thinkingConfig?)
          'thinkingConfig': thinkingConfig,
      };
}

/// Type of task for which the embedding will be used.
enum TaskType {
  /// Unset value, which will default to one of the other enum values.
  unspecified,

  /// Specifies the given text is a query in a search/retrieval setting.
  retrievalQuery,

  /// Specifies the given text is a document from the corpus being searched.
  retrievalDocument,

  /// Specifies the given text will be used for STS.
  semanticSimilarity,

  /// Specifies that the given text will be classified.
  classification,

  /// Specifies that the embeddings will be used for clustering.
  clustering;

  String toJson() => switch (this) {
        unspecified => 'TASK_TYPE_UNSPECIFIED',
        retrievalQuery => 'RETRIEVAL_QUERY',
        retrievalDocument => 'RETRIEVAL_DOCUMENT',
        semanticSimilarity => 'SEMANTIC_SIMILARITY',
        classification => 'CLASSIFICATION',
        clustering => 'CLUSTERING'
      };
}

GenerateContentResponse parseGenerateContentResponse(Object jsonObject) {
  if (jsonObject case {'error': final Object error}) throw parseError(error);
  final candidates = switch (jsonObject) {
    {'candidates': final List<Object?> candidates} =>
      candidates.map(_parseCandidate).toList(),
    _ => <Candidate>[]
  };
  final promptFeedback = switch (jsonObject) {
    {'promptFeedback': final promptFeedback?} =>
      _parsePromptFeedback(promptFeedback),
    _ => null,
  };
  final usageMedata = switch (jsonObject) {
    {'usageMetadata': final usageMetadata?} =>
      _parseUsageMetadata(usageMetadata),
    _ => null,
  };
  return GenerateContentResponse(candidates, promptFeedback,
      usageMetadata: usageMedata);
}

CountTokensResponse parseCountTokensResponse(Object jsonObject) {
  if (jsonObject case {'error': final Object error}) throw parseError(error);
  if (jsonObject case {'totalTokens': final int totalTokens}) {
    final extraFields = {
      for (final entry in jsonObject.entries)
        if (entry.key case final String fieldName
            when fieldName != 'totalTokens')
          fieldName: entry.value
    };
    return CountTokensResponse._(totalTokens,
        extraFields.isEmpty ? null : Map.unmodifiable(extraFields));
  }
  throw unhandledFormat('CountTokensResponse', jsonObject);
}

EmbedContentResponse parseEmbedContentResponse(Object jsonObject) {
  return switch (jsonObject) {
    {'embedding': final Object embedding} =>
      EmbedContentResponse(_parseContentEmbedding(embedding)),
    {'error': final Object error} => throw parseError(error),
    _ => throw unhandledFormat('EmbedContentResponse', jsonObject)
  };
}

BatchEmbedContentsResponse parseBatchEmbedContentsResponse(Object jsonObject) {
  return switch (jsonObject) {
    {'embeddings': final List<Object?> embeddings} =>
      BatchEmbedContentsResponse(
          embeddings.map(_parseContentEmbedding).toList()),
    {'error': final Object error} => throw parseError(error),
    _ => throw unhandledFormat('EmbedContentResponse', jsonObject)
  };
}

Candidate _parseCandidate(Object? jsonObject) {
  if (jsonObject is! Map) {
    throw unhandledFormat('Candidate', jsonObject);
  }

  return Candidate(
    jsonObject.containsKey('content')
        ? parseContent(jsonObject['content'] as Object)
        : Content(null, []),
    switch (jsonObject) {
      {'safetyRatings': final List<Object?> safetyRatings} =>
        safetyRatings.map(_parseSafetyRating).toList(),
      _ => null
    },
    switch (jsonObject) {
      {'citationMetadata': final Object citationMetadata} =>
        _parseCitationMetadata(citationMetadata),
      _ => null
    },
    switch (jsonObject) {
      {'finishReason': final Object finishReason} =>
        FinishReason._parseValue(finishReason),
      _ => null
    },
    switch (jsonObject) {
      {'finishMessage': final String finishMessage} => finishMessage,
      _ => null
    },
  );
}

PromptFeedback _parsePromptFeedback(Object jsonObject) {
  return switch (jsonObject) {
    {
      'safetyRatings': final List<Object?> safetyRatings,
    } =>
      PromptFeedback(
          switch (jsonObject) {
            {'blockReason': final String blockReason} =>
              BlockReason._parseValue(blockReason),
            _ => null,
          },
          switch (jsonObject) {
            {'blockReasonMessage': final String blockReasonMessage} =>
              blockReasonMessage,
            _ => null,
          },
          safetyRatings.map(_parseSafetyRating).toList()),
    _ => throw unhandledFormat('PromptFeedback', jsonObject),
  };
}

UsageMetadata _parseUsageMetadata(Object jsonObject) {
  if (jsonObject is! Map<String, Object?>) {
    throw unhandledFormat('UsageMetadata', jsonObject);
  }
  final promptTokenCount = switch (jsonObject) {
    {'promptTokenCount': final int promptTokenCount} => promptTokenCount,
    _ => null,
  };
  final candidatesTokenCount = switch (jsonObject) {
    {'candidatesTokenCount': final int candidatesTokenCount} =>
      candidatesTokenCount,
    _ => null,
  };
  final totalTokenCount = switch (jsonObject) {
    {'totalTokenCount': final int totalTokenCount} => totalTokenCount,
    _ => null,
  };
  final thoughtsTokenCount = switch (jsonObject) {
    {'thoughtsTokenCount': final int thoughtsTokenCount} => thoughtsTokenCount,
    _ => null,
  };
  return UsageMetadata(
    promptTokenCount: promptTokenCount,
    candidatesTokenCount: candidatesTokenCount,
    totalTokenCount: totalTokenCount,
    thoughtsTokenCount: thoughtsTokenCount,
  );
}

SafetyRating _parseSafetyRating(Object? jsonObject) {
  return switch (jsonObject) {
    {
      'category': final Object category,
      'probability': final Object probability
    } =>
      SafetyRating(HarmCategory._parseValue(category),
          HarmProbability._parseValue(probability)),
    _ => throw unhandledFormat('SafetyRating', jsonObject),
  };
}

ContentEmbedding _parseContentEmbedding(Object? jsonObject) {
  return switch (jsonObject) {
    {'values': final List<Object?> values} => ContentEmbedding(<double>[
        ...values.cast<double>(),
      ]),
    _ => throw unhandledFormat('ContentEmbedding', jsonObject),
  };
}

CitationMetadata _parseCitationMetadata(Object? jsonObject) {
  return switch (jsonObject) {
    {'citationSources': final List<Object?> citationSources} =>
      CitationMetadata(citationSources.map(_parseCitationSource).toList()),
    // Vertex SDK format uses `citations`
    {'citations': final List<Object?> citationSources} =>
      CitationMetadata(citationSources.map(_parseCitationSource).toList()),
    _ => throw unhandledFormat('CitationMetadata', jsonObject),
  };
}

CitationSource _parseCitationSource(Object? jsonObject) {
  if (jsonObject is! Map) {
    throw unhandledFormat('CitationSource', jsonObject);
  }

  final uriString = jsonObject['uri'] as String?;

  return CitationSource(
    jsonObject['startIndex'] as int?,
    jsonObject['endIndex'] as int?,
    uriString != null ? Uri.parse(uriString) : null,
    jsonObject['license'] as String?,
  );
}
