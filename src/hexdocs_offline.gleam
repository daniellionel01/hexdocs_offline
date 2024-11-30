import gleam/list
import gleam/string
import glexec as exec
import hexdocs_offline/config.{type Config, default_config}
import hexdocs_offline/toml
import nakai
import nakai/attr
import nakai/html
import simplifile

pub fn main() {
  let config = default_config()
  generate(config)
}

pub fn generate(conf: Config) {
  let assert Ok(deps) = toml.get_deps(conf)

  let assert Ok(deps_with_paths) = download_docs(deps, [])
  let assert Ok(_) = ensure_permissions(conf, deps_with_paths)

  let index_file = gen_index_file(deps_with_paths)
  simplifile.write(to: conf.index_path, contents: index_file)
}

fn gen_index_file(deps: List(DownloadResult)) {
  let list_items =
    list.map(deps, fn(dep) {
      let path = dep.path <> "/index.html"
      let href = "file://" <> path
      html.li([], [html.a([attr.href(href)], [html.Text(dep.dep)])])
    })

  let head = [
    html.title("HexDocs"),
    html.meta([attr.charset("UTF-8")]),
    html.meta([
      attr.name("viewport"),
      attr.content("width=device-width, initial-scale=1.0"),
    ]),
    html.link([
      attr.rel("stylesheet"),
      attr.href("https://cdn.simplecss.org/simple.min.css"),
    ]),
  ]

  let body = [html.h1([], [html.Text("Dependencies")]), html.ul([], list_items)]

  html.Html([attr.lang("en-US")], [html.Head(head), html.Body([], body)])
  |> nakai.to_string()
}

type DownloadResult {
  DownloadResult(dep: String, path: String)
}

fn download_docs(
  deps: List(String),
  acc: List(DownloadResult),
) -> Result(List(DownloadResult), Nil) {
  case deps {
    [dep, ..rest] -> {
      let cmd = exec.Shell("mix hex.docs fetch " <> dep)
      let assert Ok(exec.Output(out)) =
        exec.new() |> exec.with_stdout(exec.StdoutCapture) |> exec.run_sync(cmd)

      let assert [exec.Stdout(lines)] = out
      let assert [line] = lines

      let assert [_, path] =
        line
        |> string.trim()
        |> string.split(":")
        |> list.map(string.trim)

      let acc = [DownloadResult(dep:, path:), ..acc]

      download_docs(rest, acc)
    }
    [] -> Ok(acc)
  }
}

fn ensure_permissions(
  conf: Config,
  deps_with_path: List(DownloadResult),
) -> Result(Nil, Nil) {
  case deps_with_path {
    [dep, ..rest] -> {
      let cmd = exec.Shell("chmod -R u+rwX " <> dep.path)
      let assert Ok(_) = exec.new() |> exec.run_sync(cmd)

      ensure_permissions(conf, rest)
    }
    [] -> Ok(Nil)
  }
}
