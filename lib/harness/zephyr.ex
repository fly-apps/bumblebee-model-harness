defmodule Harness.Zephyr do
 @moduledoc """
  Define the Zephyr 7B serving.

  - https://zephyr-7b.net/
  - https://huggingface.co/HuggingFaceH4/zephyr-7b-beta
  """

  def serving() do
    mistral = {:hf, "HuggingFaceH4/zephyr-7b-beta"}

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
