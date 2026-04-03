defmodule Mix.Tasks.Starter.Install do
  @shortdoc "Import files from the phoenix_starter remote into this project"
  @moduledoc """
  Imports infrastructure files from the `starter` git remote, replacing
  starter-specific names with the current project's names.

      mix starter.install
      mix starter.install --dry-run
      mix starter.install --file scripts/sandbox.sh --file .gitignore

  ## Options

    * `--dry-run` - Show what would change without writing files
    * `--file` - Import only specific files (can be repeated)

  ## Prerequisites

  A git remote named `starter` must exist, pointing to the phoenix_starter repo:

      git remote add starter git@github.com:1st8/phoenix_starter.git

  """

  use Mix.Task

  @starter_files [
    "scripts/sandbox.sh",
    "scripts/sandbox-setup.sh",
    "scripts/sandbox-signal.sh",
    ".gitignore",
    ".dockerignore",
    ".claude/skills/",
    "Dockerfile",
    "docker-compose.yml",
    "LOOPS.md",
    "CLAUDE.md",
    "mix.exs"
  ]

  @starter_branch "starter/main"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [dry_run: :boolean, file: :keep])

    dry_run? = Keyword.get(opts, :dry_run, false)
    file_filter = Keyword.get_values(opts, :file)

    app_name = Mix.Project.config()[:app] |> Atom.to_string()
    module_name = app_name |> Macro.camelize()
    kebab_name = String.replace(app_name, "_", "-")

    with :ok <- check_starter_remote(),
         :ok <- fetch_starter() do
      files = resolve_files(file_filter)

      results =
        Enum.flat_map(files, fn path ->
          import_path(path, app_name, module_name, kebab_name, dry_run?)
        end)

      print_summary(results, dry_run?)
    end
  end

  defp check_starter_remote do
    case System.cmd("git", ["remote", "get-url", "starter"], stderr_to_stdout: true) do
      {_url, 0} ->
        :ok

      {_, _} ->
        Mix.raise("""
        No "starter" git remote found.

        Add it with:
            git remote add starter git@github.com:1st8/phoenix_starter.git
        """)
    end
  end

  defp fetch_starter do
    Mix.shell().info("Fetching from starter remote...")

    case System.cmd("git", ["fetch", "starter"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {output, _} ->
        Mix.raise("Failed to fetch from starter remote:\n#{output}")
    end
  end

  defp resolve_files([]) do
    @starter_files
  end

  defp resolve_files(filter) do
    Enum.filter(@starter_files, fn path ->
      Enum.any?(filter, fn f ->
        f == path || String.starts_with?(path, f) || String.starts_with?(f, path)
      end)
    end)
    |> case do
      [] ->
        # If no predefined files match, use the filter paths directly
        filter

      matched ->
        matched
    end
  end

  defp import_path(path, app_name, module_name, kebab_name, dry_run?) do
    if String.ends_with?(path, "/") do
      import_directory(path, app_name, module_name, kebab_name, dry_run?)
    else
      import_file(path, app_name, module_name, kebab_name, dry_run?)
    end
  end

  defp import_directory(dir_path, app_name, module_name, kebab_name, dry_run?) do
    # List files in the directory from the starter branch using ls-tree
    case System.cmd("git", ["ls-tree", "-r", "--name-only", @starter_branch, dir_path],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn file_path ->
          import_file(file_path, app_name, module_name, kebab_name, dry_run?)
        end)

      {_, _} ->
        Mix.shell().info("  ⚠ Directory not found in starter: #{dir_path}")
        [{:skipped, dir_path, "not found in starter"}]
    end
  end

  defp import_file(file_path, app_name, module_name, kebab_name, dry_run?) do
    case System.cmd("git", ["show", "#{@starter_branch}:#{file_path}"], stderr_to_stdout: true) do
      {content, 0} ->
        transformed =
          content
          |> String.replace("phoenix_starter", app_name)
          |> String.replace("PhoenixStarter", module_name)
          |> String.replace("phoenix-starter", kebab_name)

        status = file_status(file_path, transformed)

        if dry_run? do
          print_dry_run(file_path, status)
        else
          write_file(file_path, transformed)
        end

        [{status, file_path}]

      {_, _} ->
        Mix.shell().info("  ⚠ Not found in starter: #{file_path}")
        [{:skipped, file_path, "not found in starter"}]
    end
  end

  defp file_status(file_path, new_content) do
    case File.read(file_path) do
      {:ok, existing} ->
        if existing == new_content, do: :unchanged, else: :updated

      {:error, :enoent} ->
        :created
    end
  end

  defp write_file(file_path, content) do
    file_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(file_path, content)
  end

  defp print_dry_run(file_path, :created) do
    Mix.shell().info("  + #{file_path} (new file)")
  end

  defp print_dry_run(file_path, :updated) do
    Mix.shell().info("  ~ #{file_path} (modified)")
  end

  defp print_dry_run(file_path, :unchanged) do
    Mix.shell().info("  = #{file_path} (unchanged)")
  end

  defp print_summary(results, dry_run?) do
    created = Enum.count(results, &match?({:created, _}, &1))
    updated = Enum.count(results, &match?({:updated, _}, &1))
    unchanged = Enum.count(results, &match?({:unchanged, _}, &1))
    skipped = Enum.count(results, &match?({:skipped, _, _}, &1))

    prefix = if dry_run?, do: "[dry-run] ", else: ""

    Mix.shell().info("""

    #{prefix}Starter install complete:
      #{created} created, #{updated} updated, #{unchanged} unchanged, #{skipped} skipped
    """)
  end
end
