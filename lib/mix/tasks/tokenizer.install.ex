defmodule Mix.Tasks.Tokenizer.Install do
  use Mix.Task

  @shortdoc "Installs Tiktokenex rank files into its dependency directory"

  @rank_files ~w(cl100k_base.tiktoken o200k_base.tiktoken)

  @impl Mix.Task
  def run(_args) do
    project_root = Mix.Project.project_file() |> Path.dirname()
    source_dir = Path.join(project_root, "priv/tiktokenex/ranks")
    destination_dir = Path.join([Mix.Project.deps_path(), "tiktokenex", "priv", "ranks"])

    unless File.dir?(Path.join(Mix.Project.deps_path(), "tiktokenex")) do
      Mix.raise("Tiktokenex is not installed. Run `mix deps.get` first.")
    end

    File.mkdir_p!(destination_dir)

    Enum.each(@rank_files, fn filename ->
      source = Path.join(source_dir, filename)
      destination = Path.join(destination_dir, filename)

      unless File.regular?(source) do
        Mix.raise("Missing Tiktokenex rank file: #{source}")
      end

      File.cp!(source, destination)
    end)

    Mix.shell().info("Installed Tiktokenex rank files.")
  end
end
