defmodule Harness.Zephyr do
  @moduledoc """
  Define the Zephyr 7B serving.

  - https://zephyr-7b.net/
  - https://huggingface.co/HuggingFaceH4/zephyr-7b-beta
  """

  def serving() do
    # NOTE: After the model is downloaded, you can toggle to `offline: true` to
    #       only use the locally cached files and not reach out to HF at all.
    zephyr = {:hf, "HuggingFaceH4/zephyr-7b-beta", offline: false}

    {:ok, model_info} = Bumblebee.load_model(zephyr, type: :bf16, backend: EXLA.Backend)

    {:ok, tokenizer} = Bumblebee.load_tokenizer(zephyr)

    {:ok, generation_config} = Bumblebee.load_generation_config(zephyr)

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
