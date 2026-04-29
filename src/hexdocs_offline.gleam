import child_process
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import hexdocs_offline/config.{type Config, default_config}
import hexdocs_offline/internal/toml.{type Dependency}
import nakai
import nakai/attr
import nakai/html
import simplifile

pub fn main() {
  let config = default_config()
  generate(config)
}

pub fn generate(conf: Config) {
  use deps <- result.try(toml.get_deps(conf))

  io.println(
    "Dependencies fetched: "
    <> { list.map(deps, fn(dep) { dep.name }) |> string.join(", ") },
  )

  io.println("Downloading Docs...")
  let assert Ok(deps_with_paths) = download_docs(deps, [])
  let assert Ok(_) = ensure_permissions(deps_with_paths)

  let output = gen_output(conf, deps_with_paths)
  let assert Ok(_) = simplifile.write(to: conf.output_path, contents: output)

  io.println("Output Successfull: " <> conf.output_path)

  Ok(Nil)
}

fn gen_output(conf: Config, deps: List(DownloadResult)) {
  let list_items =
    list.map(deps, fn(dep) {
      let path = dep.path <> "/index.html"
      let href = "file://" <> path

      let target = case conf.new_tab {
        True -> attr.target("_blank")
        False -> attr.target("_self")
      }

      html.li([], [html.a([attr.href(href), target], [html.Text(dep.dep.name)])])
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
  DownloadResult(dep: Dependency, path: String)
}

fn download_docs(
  deps: List(Dependency),
  acc: List(DownloadResult),
) -> Result(List(DownloadResult), Nil) {
  case deps {
    [dep, ..rest] -> {
      let fetch_result =
        child_process.shell(
          "mix hex.docs fetch " <> dep.name <> " " <> dep.version,
        )

      case fetch_result {
        Ok(stdout) -> {
          let extracted =
            stdout
            |> string.trim()
            |> string.split(":")
            |> list.map(string.trim)

          case extracted {
            [_, path] -> {
              let acc = [DownloadResult(dep:, path:), ..acc]
              download_docs(rest, acc)
            }
            _ -> download_docs(rest, acc)
          }
        }
        Error(_) -> {
          io.println(
            "Could not fetch docs for '"
            <> dep.name
            <> "' (v"
            <> dep.version
            <> ")",
          )

          download_docs(rest, acc)
        }
      }
    }
    [] -> Ok(acc)
  }
}

fn ensure_permissions(
  deps_with_path: List(DownloadResult),
) -> Result(Nil, Nil) {
  case deps_with_path {
    [dep, ..rest] -> {
      let assert Ok(_) = child_process.shell("chmod -R u+rwX " <> dep.path)
      ensure_permissions(rest)
    }
    [] -> Ok(Nil)
  }
}
