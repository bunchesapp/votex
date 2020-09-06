defmodule Votex.Voter do
  @moduledoc """
  Defines a Voter Model

  A Voter model will expose the required methods to enable voting functionality
  Typically be used by models like User, Team, Organization etc.

  ## Example
      defmodule User do
        use Ecto.Schema
        use Votex.Voter
        schema "users" do
          field :name, :string
          field :age, :integer, default:  20
        end
      end
  """

  import Ecto.Query
  import Votex.Core
  alias Votex.{Vote, Voter, Votable, DB}

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      defdelegate votes_by(voter), to: Voter
      defdelegate voted_for?(voter, votable), to: Voter
      defdelegate cleanup_votes(result), to: Voter
    end
  end

  @doc """
  Get a list of votes by voter

  ## Example

      votes = user |> User.votes_by

  """

  def votes_by(%{} = voter, preload \\ false) do
    { _, voter_type } = extract_fields(nil, voter)
    voter_id = get_id_for(voter_type, voter)
    votes = Vote
            |> where(voter_type: ^voter_type)
            |> where(voter_id: ^voter_id)
            |> DB.repo().all()
    case preload do
      true -> votes |> preload_votes
      false -> votes
    end
  end

  @doc """
  Check if a votable record has been voted by a voter

  ## Example

      voted = user |> User.voted_for? post

  """

  def voted_for?(%{} = voter, %{} = votable) do
    {votable_type, voter_type} = extract_fields(votable, voter)
    votable_id = get_id_for(votable_type, votable)
    voter_id = get_id_for(voter_type, voter)

    case Vote
         |> where(voter_type: ^voter_type)
         |> where(voter_id: ^voter_id)
         |> where(votable_type: ^votable_type)
         |> where(votable_id: ^votable_id)
         |> DB.repo().one() do
      %{} -> true
      nil -> false
    end
  end

  @doc """
  Clean up votes after a voter record is deleted

  ## Example

      Repo.delete(post) |> Post.cleanup_votes

  """

  def cleanup_votes({status, %{} = payload}) do
    case status do
      :ok ->
        {_, voter_type} = extract_fields(nil, payload)

        payload_id = get_id_for(voter_type, payload)

        votes =
          Vote
          |> where(voter_type: ^voter_type)
          |> where(voter_id: ^payload_id)
          |> DB.repo().all()

        modules =
          Votable.children()
          |> convert_modules_list_to_map

        for {id, type} <- votes |> Enum.map(fn vote -> {vote.votable_id, vote.votable_type} end),
            do: calculate_cached_fields_for_votable(modules |> Map.get(type), type, id, false)

        Vote
        |> where(voter_type: ^voter_type)
        |> where(voter_id: ^payload_id)
        |> DB.repo().delete_all

      _ ->
        {status, payload}
    end
  end

  @doc """
  Reserved for internal use
  """

  def children() do
    for({module, _} <- :code.all_loaded(), do: module)
    |> Enum.filter(&is_child?/1)
  end

  # Private

  defp is_child?(module) do
    module.module_info[:attributes]
    |> Enum.member?({:behaviour, [__MODULE__]})
  end
end
