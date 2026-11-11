# TraceMeet

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Tiktokenex Rank Files

Download the two Tiktokenex rank files into the directory below:

```bash
mkdir -p priv/tiktokenex/ranks

curl -fL https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken \
  -o priv/tiktokenex/ranks/cl100k_base.tiktoken

curl -fL https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken \
  -o priv/tiktokenex/ranks/o200k_base.tiktoken
```

Both files are required because `Tiktokenex.Ranks.warmup/0` loads all encodings supported by the library.

After downloading them, run `mix tokenizer.install` to copy the files into Tiktokenex's private directory. The `mix setup` alias runs this task automatically after fetching dependencies, and the `mix release` alias runs it before assembling a release. The application therefore only loads the rank files at startup; it does not write to the release filesystem.


## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
