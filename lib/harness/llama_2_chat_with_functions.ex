defmodule Harness.Llama2ChatFunctions do
  @moduledoc """
  Define the Llama 2 serving.

  - https://huggingface.co/Trelis/Llama-2-7b-chat-hf-function-calling-v3
  """

  def serving() do
    llama_2 = {:hf, "Trelis/Llama-2-7b-chat-hf-function-calling-v3"}

    {:ok, model_info} = Bumblebee.load_model(llama_2, type: :bf16, backend: EXLA.Backend)

    {:ok, tokenizer} = Bumblebee.load_tokenizer(llama_2)

    {:ok, generation_config} = Bumblebee.load_generation_config(llama_2)

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
