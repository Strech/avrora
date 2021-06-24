defmodule Avrora.ConfigTest do
  use ExUnit.Case, async: true
  doctest Avrora.Config

  alias Avrora.Config

  describe "schemas_path/0" do
    test "when otp_app is set" do
      schemas_path = Application.get_env(:avrora, :schemas_path)
      otp_app = Application.get_env(:avrora, :otp_app)

      Application.put_env(:avrora, :schemas_path, "./some/path")
      Application.put_env(:avrora, :otp_app, :area)
      Code.prepend_path("test/fixtures/area-52/ebin")

      assert Config.schemas_path() =~ "avrora/test/fixtures/area-52/./some/path"

      Application.put_env(:avrora, :schemas_path, schemas_path)
      Application.put_env(:avrora, :otp_app, otp_app)
    end

    test "when otp_app is not set" do
      schemas_path = Application.get_env(:avrora, :schemas_path)
      Application.put_env(:avrora, :schemas_path, "./some/path")

      assert Config.schemas_path() =~ "avrora/some/path"

      Application.put_env(:avrora, :schemas_path, schemas_path)
    end
  end
end
