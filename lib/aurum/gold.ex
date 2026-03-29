defmodule Aurum.Gold do
  @moduledoc """
  The Gold context.
  """

  import Ecto.Query
  alias Aurum.Repo
  alias Aurum.Gold.Holding
  alias Aurum.Gold.Price

  defdelegate categories, to: Holding
  defdelegate weight_units, to: Holding

  @doc """
  Returns the list of holdings.
  """
  def list_holdings do
    Repo.all(Holding)
  end

  @doc """
  Gets a single holding.

  Raises `Ecto.NoResultsError` if the Holding does not exist.
  """
  def get_holding!(id), do: Repo.get!(Holding, id)

  @doc """
  Gets a single holding.

  Returns `{:ok, holding}` or `{:error, :not_found}`.
  """
  def get_holding(id) do
    case Repo.get(Holding, id) do
      nil -> {:error, :not_found}
      holding -> {:ok, holding}
    end
  end

  @doc """
  Creates a holding.
  """
  def create_holding(attrs \\ %{}) do
    %Holding{}
    |> Holding.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a holding.
  """
  def update_holding(%Holding{} = holding, attrs) do
    holding
    |> Holding.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a holding.
  """
  def delete_holding(%Holding{} = holding) do
    Repo.delete(holding)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking holding changes.
  """
  def change_holding(%Holding{} = holding, attrs \\ %{}) do
    Holding.changeset(holding, attrs)
  end

  @doc """
  Returns the list of prices.
  """
  def list_prices do
    Repo.all(from p in Price, order_by: [desc: p.fetched_at])
  end

  @doc """
  Gets the latest price.
  """
  def latest_price do
    Repo.one(from p in Price, order_by: [desc: p.fetched_at], limit: 1)
  end

  @doc """
  Creates a price.
  """
  def create_price(attrs \\ %{}) do
    %Price{}
    |> Price.changeset(attrs)
    |> Repo.insert()
  end
end
