defmodule Votex.Votable do
  @moduledoc """
  Defines a Votable Model

  A Votable model will expose the required methods to enable voting functionality
  Typically be used by models like Post, Image, Answer etc.

  ## Example
      defmodule Post do
        use Ecto.Schema
        use Votex.Votable
        schema "posts" do
          field :title, :string
          field :views, :integer, default:  0
        end
      end
  """

  import Ecto.Query
  import Votex.Core
  alias Votex.{DB, Votable, Vote}

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      defdelegate vote_by(votable, voter), to: Votable
      defdelegate unvote_by(votable, voter), to: Votable
      defdelegate votes_for(votable), to: Votable
      defdelegate cleanup_votable(result), to: Votable
    end
  end

  @callback cleanup_votable(tuple()) :: tuple()

  @doc """
  Primary method to cast a vote

  ## Example

      {:ok, vote} = post |> Post.vote_by user

  """

  def vote_by(votable, voter) do
    {votable_type, voter_type} = extract_fields(votable, voter)

    votable_id = get_id_for(votable_type, votable)
    voter_id = get_id_for(voter_type, voter)

    result =
      %{
        votable_id: votable_id,
        votable_type: votable_type,
        voter_id: voter_id,
        voter_type: voter_type
      }
      |> create_vote

    calculate_cached_fields_for_votable(get_module(votable_type), votable_type, votable_id, true)
    result
  end

  @doc """
  Primary method to remove a vote

  ## Example

      {:ok, vote} = post |> Post.unvote_by user

  """

  def unvote_by(votable, voter) do
    {votable_type, voter_type} = extract_fields(votable, voter)

    votable_id = get_id_for(votable_type, votable)
    voter_id = get_id_for(voter_type, voter)

    vote =
      Vote
      |> where(votable_type: ^votable_type)
      |> where(votable_id: ^votable_id)
      |> where(voter_type: ^voter_type)
      |> where(voter_id: ^voter_id)
      |> DB.repo().one

    case vote do
      %{} = v ->
        calculate_cached_fields_for_votable(
          get_module(votable_type),
          votable_type,
          votable_id,
          false
        )

        v |> DB.repo().delete

      nil ->
        raise "Vote not present"
    end
  end

  @doc """
  Get a list of votes on votable record

  ## Example

      votes = post |> Post.votes_for

  """

  def votes_for(votable) do
    {votable_type, _} = extract_fields(votable, nil)

    votable_id = get_id_for(votable_type, votable)

    Vote
    |> where(votable_type: ^votable_type)
    |> where(votable_id: ^votable_id)
    |> DB.repo().all
    |> preload_votes
  end

  @doc """
  Clean up votes after a votable record is deleted

  ## Example

      Repo.delete(user) |> User.cleanup_votable

  """

  def cleanup_votable({status, %{} = payload}) do
    case status do
      :ok ->
        {votable_type, _} = extract_fields(payload, nil)

        payload_id = get_id_for(votable_type, payload)

        Vote
        |> where(votable_type: ^votable_type)
        |> where(votable_id: ^payload_id)
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

  defp get_module(type) do
    children()
    |> convert_modules_list_to_map
    |> Map.get(type)
  end

  defp is_child?(module) do
    module.module_info[:attributes]
    |> Enum.member?({:behaviour, [__MODULE__]})
  end

  defp create_vote(%{} = vote) do
    %Vote{}
    |> Vote.changeset(vote)
    |> DB.repo().insert
  end
end
