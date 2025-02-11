defmodule Lexical.Server.CodeIntelligence.Completion do
  alias Lexical.Completion.Translatable
  alias Lexical.Project
  alias Lexical.Protocol.Types.Completion
  alias Lexical.Protocol.Types.InsertTextFormat
  alias Lexical.RemoteControl
  alias Lexical.RemoteControl.Completion.Result
  alias Lexical.Server.CodeIntelligence.Completion.Builder
  alias Lexical.Server.CodeIntelligence.Completion.Env
  alias Lexical.Server.Project.Intelligence
  alias Lexical.SourceFile
  alias Lexical.SourceFile.Position

  require InsertTextFormat
  require Logger

  @lexical_deps Enum.map([:lexical | Mix.Project.deps_apps()], &Atom.to_string/1)

  @lexical_dep_modules Enum.map(@lexical_deps, &Macro.camelize/1)

  def trigger_characters do
    [".", "@", "&", "%", "^", ":", "!", "-", "~"]
  end

  @spec complete(Project.t(), SourceFile.t(), Position.t(), Completion.Context.t()) :: [
          Completion.Item
        ]
  def complete(
        %Project{} = project,
        %SourceFile{} = document,
        %Position{} = position,
        %Completion.Context{} = context
      ) do
    {:ok, env} = Env.new(project, document, position)
    completions = completions(project, env, context)
    Logger.warning("Emitting completions: #{inspect(completions)}")
    completions
  end

  defp to_completion_items(
         local_completions,
         %Project{} = project,
         %Env{} = env,
         %Completion.Context{} = context
       ) do
    Logger.info("Local completions are #{inspect(local_completions)}")

    for result <- local_completions,
        displayable?(project, result),
        applies_to_context?(project, result, context),
        %Completion.Item{} = item <- List.wrap(Translatable.translate(result, Builder, env)) do
      item
    end
  end

  defp completions(%Project{} = project, %Env{} = env, %Completion.Context{} = context) do
    cond do
      Env.last_word(env) == "do" and Env.empty?(env.suffix) ->
        insert_text = "do\n$0\nend"

        [
          Completion.Item.new(
            label: "do/end",
            insert_text_format: :snippet,
            insert_text: insert_text
          )
        ]

      String.length(Env.last_word(env)) == 1 ->
        []

      true ->
        project
        |> RemoteControl.Api.complete(env.document, env.position)
        |> to_completion_items(project, env, context)
    end
  end

  defp displayable?(%Project{} = project, result) do
    # Don't exclude a dependency if we're working on that project!
    if Project.name(project) in @lexical_deps do
      true
    else
      suggested_module =
        case result do
          %_{full_name: full_name} -> full_name
          %_{origin: origin} -> origin
          _ -> ""
        end

      Enum.reduce_while(@lexical_dep_modules, true, fn module, _ ->
        if String.starts_with?(suggested_module, module) do
          {:halt, false}
        else
          {:cont, true}
        end
      end)
    end
  end

  defp applies_to_context?(%Project{} = project, result, %Completion.Context{
         trigger_kind: :trigger_character,
         trigger_character: "%"
       }) do
    case result do
      %Result.Module{} = result ->
        Intelligence.child_defines_struct?(project, result.full_name)

      %Result.Struct{} ->
        true

      _other ->
        false
    end
  end

  defp applies_to_context?(_project, _result, _context) do
    true
  end
end
