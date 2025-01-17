import Foundation

struct LLMModelSettings: Hashable, Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var comment: String?

    /// OpenAI - Whether or not to store the output of this chat complation
    ///   for use in model distillaton or evals products
    var store: Bool?

    /// OpenAI - o1 Models Only
    /// 
    /// 
    ///   Details as of 01/13/2025
    ///     o1 - context window 200,000 tokens, up to 100,000 output tokens
    ///     o1-mini -- context window 128,000 tokens, up to 65,536 output tokens
    /// 
    ///     values of "low", "medium", and "high" are supported.
    ///     default: "medium"
    ///
    /// These models also generate "reasoning tokens", which are discarded
    ///
    /// o1 models also now have "developer" messages, in addition to user messages
    /// and platform messages.  Basically don't be using system messages on these.
    /// use 'developer' instead.
    ///
    /// o1 models are available to Tier 5 customers only, do not support streaming or
    /// the batch API, and do not support these parameters:
    ///     
    ///     - temperature
    ///     - top_p
    ///     - frequency_penalty
    ///     - presence_penalty
    ///     - logprobs
    ///     - top_logprobs
    ///     - logit_bias
    ///
    /// Starting with o1-2024-12-17, markdown responses are generally suppressed, but
    /// can be re-enabled with "Formatting re-enabled" on the first line of your "developer"
    /// message.
    var reasoning_effort: String?

    /// Available beginning with o1 models, max_completion_tokens limits
    /// the total number of tokens generated, including both response tokens
    /// and reasoning tokens.
    /// 
    /// The older "max_tokens" will continue to restrict just the number of
    /// generated response tokens.
    var max_completion_tokens: Int?

    /// Maximum number of tokens allowed in response ("max_tokens").  See above.
    /// Technically this is deprecated, per the openai documentation, here:
    /// https://platform.openai.com/docs/api-reference/chat/create
    ///
    /// Not compatible o1 models
    /// 
    /// Anthropic Claude - max_tokens is required.
    var maxTokens: Int? 

    /// OpenAI:
    /// What sampling temperature to use, between 0 and 2. Higher values like 0.8 will 
    /// make the output more random, while lower values like 0.2 will make it more focused
    /// and deterministic. 
    /// 
    /// We generally recommend altering this or top_p but not both.
    /// Defaults to 1
    ///
    /// Claude:
    /// Amount of randomness injected into the response.
    /// 
    /// Defaults to 1.0. Ranges from 0.0 to 1.0. Use temperature closer to 0.0 for analytical / 
    /// multiple choice, and closer to 1.0 for creative and generative tasks.
    /// 
    /// Note that even with temperature of 0.0, the results will not be fully deterministic.
    /// Defaults to 1.0
    var temperature: Double?
    
    /// OpenAI:
    /// An alternative to sampling with temperature, called nucleus sampling, where the model 
    /// considers the results of the tokens with top_p probability mass. So 0.1 means only the
    /// tokens comprising the top 10% probability mass are considered.
    /// We generally recommend altering this or temperature but not both.
    /// 
    /// Defaults to 1
    /// 
    /// Claude:
    /// Use nucleus sampling.
    /// 
    /// In nucleus sampling, we compute the cumulative distribution over all the options for each
    /// subsequent token in decreasing probability order and cut it off once it reaches a particular
    /// probability specified by top_p. You should either alter temperature or top_p, but not both.
    /// 
    /// Recommended for advanced use cases only. You usually only need to use temperature.
    /// 
    /// Required range: 0 < x < 1
    /// 
    var top_p: Double?

    /// OpenAI:
    /// How many chat completion choices to generate for each input message. 
    /// Note that you will be charged based on the number of generated tokens 
    /// across all of the choices. Keep n as 1 to minimize costs
    ///
    /// Defaults to 1
    var n: Int?


    /// Claude:
    /// Only sample from the top K options for each subsequent token.
    /// Used to remove "long tail" low probability responses. Learn more technical details here.
    /// 
    /// Recommended for advanced use cases only. You usually only need to use temperature.
    /// 
    /// Defaults to null
    /// 
    /// Required range: x > 0
    var top_k: Int?

    /// Number between -2.0 and 2.0.  Positivre values penalize new tokens based on their
    /// existing frequency in the text so far, decreasing the model's likelihood to repeat
    /// the same line verbatim.  Defaults to 0.
    var frequency_penalty: Double?

    /// Number between -2.0 and 2.0. Positive values penalize new tokens based on whether 
    /// they appear in the text so far, increasing the model's likelihood to talk about new 
    /// topics.
    var presence_penalty: Double?

    /// Modifies the likelihood of specified tokens appearing in the completion
    /// 
    /// Accepts a JSON object that maps tokens (specified by their token ID in the tokenizer) to an
    /// associated bias value from -100 to 100. Mathematically, the bias is added to the logits 
    /// generated by the model prior to sampling. The exact effect will vary per model, but values 
    /// between -1 and 1 should decrease or increase likelihood of selection; values like -100 or 
    /// 100 should result in a ban or exclusive selection of the relevant token.
    ///
    /// Defaults to null
    var logit_bias: Dictionary<String, Double>?

    /// Whether to return log probabilities of the output tokens or not. If true, returns the
    /// log probabilities of each output token returned in the content of message
    var logprobs: Bool?

    /// An integer between 0 and 20 specifying the number of most likely tokens to return at each 
    /// token position, each with an associated log probability. logprobs must be set to true if 
    /// this parameter is used
    var top_logprobs: Int?

    /// Developer-defined tags and values for filtering in dashboard
    /// var metadata: Object-Or-Null

    /// Array of output types you'd like the model to generate.
    /// text, audio, etc.
    /// 
    /// Defaults to ["text"]
    /// var modalities: [String]?

    /// tools, tool_choice, parallel_tool_calls -- all for defining tools that the model can
    /// "call back" into -- as part of its response
    
    /// OpenAI only: A unique identifier or hash used to represent a user.  Used to identify abuse.
    /// var user: String?

    /// Claude only: 
    /// An external identifier for the user who is associated with the request.
    /// This should be a uuid, hash value, or other opaque identifier. Anthropic may use this id to help
    /// detect abuse. Do not include any identifying information such as name, email address, or phone number
    /// var metadata.user_id: String?

    /// With Claude, a system prompt is a separate parameter from messages.  From
    /// OpenAI, system is part of the messages array, though it might also be referred
    /// to as a "platform" message, or in o1 and later models, they seem to have renamed
    /// it to "developer".
    /// 
    /// var system: String?

    init(
        id: UUID = UUID(),
        name: String,
        comment: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
} 