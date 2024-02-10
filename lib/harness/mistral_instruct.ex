defmodule Harness.MistralInstruct do
  @moduledoc """
  Define the Mistral 7B serving.

  - https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.1
  - https://docs.mistral.ai/
  """
  def serving() do
    mistral = {:hf, "mistralai/Mistral-7B-Instruct-v0.2"}

    {:ok, spec} =
      Bumblebee.load_spec(mistral,
        module: Bumblebee.Text.Mistral,
        architecture: :for_causal_language_modeling
      )

    {:ok, model_info} = Bumblebee.load_model(mistral, spec: spec)

    {:ok, tokenizer} = Bumblebee.load_tokenizer(mistral, module: Bumblebee.Text.LlamaTokenizer)

    {:ok, generation_config} =
      Bumblebee.load_generation_config(mistral, spec_module: Bumblebee.Text.Mistral)

    generation_config =
      Bumblebee.configure(generation_config,
        max_new_tokens: 1024,
        strategy: %{type: :multinomial_sampling, top_p: 0.6}
      )

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 4096],
      stream: true,
      # stream: false,
      defn_options: [compiler: EXLA, lazy_transfers: :never]
      # preallocate_params: true
    )
  end
end
