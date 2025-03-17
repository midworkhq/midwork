defmodule MidworkWeb.ErrorJSONTest do
  use MidworkWeb.ConnCase, async: true

  test "renders 404" do
    assert MidworkWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert MidworkWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
