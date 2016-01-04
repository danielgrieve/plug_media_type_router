defmodule PlugMediaTypeRouter do
  import Plug.Conn
  alias Plug.Conn.Status

  def init(opts), do: opts

  def call(conn, opts) do
    routers = Keyword.fetch!(opts, :routers)
    version = accept_header_version(conn, opts)

    conn
    |> pass_to_router(Dict.get(routers, version), opts)
  end

  defp accept_header_version(conn, opts) do
    default_version = Keyword.fetch!(opts, :default_version)
    name = Keyword.fetch!(opts, :name)

    conn
    |> get_req_header("accept")
    |> List.first()
    |> extract_version(name, default_version)
  end

  defp extract_version(nil, _, default_version), do: default_version
  defp extract_version(header, name, default_version) do
    pattern = ~r/application\/vnd\.#{name}\.(v\d)*/

    case Regex.scan(pattern, header) do
      [[_match, version]] -> version
      _ -> default_version
    end
  end

  defp error_message(version, opts) do
    versions =
      opts
      |> Keyword.fetch!(:routers)
      |> Dict.keys()
      |> Enum.join(", ")

    """
    API version not supported: #{version}

    Currently supported API versions: #{versions}
    """
  end

  defp pass_to_router(conn, nil, opts) do
    body = conn |> accept_header_version(opts) |> error_message(opts)

    conn
    |> send_resp(Status.code(:bad_request), body)
    |> halt()
  end

  defp pass_to_router(conn, router, _opts) do
    router.call(conn, router.init([]))
  end
end
