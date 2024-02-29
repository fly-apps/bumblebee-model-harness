defmodule Harness.MistralInstruct do
  @moduledoc """
  Define the Mistral 7B serving.

  - https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.1
  - https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2
  - https://docs.mistral.ai/
  """
  def serving() do
    # NOTE: After the model is downloaded, you can toggle to `offline: true` to
    #       only use the locally cached files and not reach out to HF at all.
    mistral = {:hf, "mistralai/Mistral-7B-Instruct-v0.2", offline: false}

    {:ok, model_info} = Bumblebee.load_model(mistral, type: :bf16, backend: EXLA.Backend)

    {:ok, tokenizer} = Bumblebee.load_tokenizer(mistral)

    {:ok, generation_config} = Bumblebee.load_generation_config(mistral)

    generation_config =
      Bumblebee.configure(generation_config,
        max_new_tokens: 1024,
        strategy: %{type: :multinomial_sampling, top_p: 0.6}
      )

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 4096],
      stream: true,
      stream_done: true,
      defn_options: [compiler: EXLA, lazy_transfers: :never]
      # preallocate_params: true
    )
  end
end
