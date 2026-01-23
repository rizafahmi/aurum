defmodule Aurum.Env do
  @moduledoc """
  Centralized environment checks to avoid repeated Application.get_env calls.
  """

  @env Application.compile_env(:aurum, :env, :prod)

  @doc """
  Returns the current environment.
  """
  @spec env() :: :dev | :test | :prod
  def env, do: @env

  @doc """
  Returns true if running in test environment.
  """
  @spec test?() :: boolean()
  def test?, do: @env == :test

  @doc """
  Returns true if running in production environment.
  """
  @spec prod?() :: boolean()
  def prod?, do: @env == :prod

  @doc """
  Returns true if running in development environment.
  """
  @spec dev?() :: boolean()
  def dev?, do: @env == :dev
end
