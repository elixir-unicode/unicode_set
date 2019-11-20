defmodule Unicode.Set.Operation do
  @moduledoc """
  A set of functions to expand Unicode sets:

  * Intersection
  * Difference
  * Ranges

  """

  @doc """
  Expands all sets, properties and ranges to a list
  of 2-tuples expressing a range of codepoints

  """

  def expand([{:and, [this, that]}]) do
    aand(expand(this), expand(that))
  end

  def expand([{:range, [from, to]}]) do
    range(from, to)
  end

  def expand([{:difference, [this, that]}]) do
    difference(expand(this), expand(that))
  end

  def expand([{:intersection, [this, that]}]) do
    intersection(expand(this), expand(that))
  end

  def expand([{:equal, [property, name]}]) do
    equal(property, name)
  end

  def expand([{:not_equal, [property, name]}]) do
    not_equal(property, name)
  end

  def range(from, to) do
    {from, to}
  end

  def aand(this, that) do

  end

  def intersection(this, that) do

  end

  def difference(this, that) do

  end

  def equal(this, that) do

  end

  def not_equal(this, that) do

  end
end