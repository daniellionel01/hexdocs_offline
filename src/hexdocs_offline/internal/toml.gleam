////
//// This module contains the function to read out the gleam.toml and
//// the contained dependencies.
//// Inspired by https://github.com/bwireman/go-over/blob/main/src/go_over/config.gleam
////

import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result.{unwrap}
import hexdocs_offline/config.{type Config}
import simplifile
import tom

pub type Dependency {
  Dependency(name: String, version: String)
}

fn filter_local_paths(in: dict.Dict(String, tom.Toml)) {
  in
  |> dict.to_list()
  |> list.filter(fn(entry) {
    let #(_, value) = entry
    case value {
      tom.String(_) -> True
      _ -> False
    }
  })
  |> dict.from_list()
}

pub type DependencyError {
  GleamFileError(simplifile.FileError)
  GleamParsingError(tom.ParseError)
  ManifestFileError(simplifile.FileError)
  ManifestParsingError(tom.ParseError)
}

pub fn get_deps(conf: Config) -> Result(List(Dependency), DependencyError) {
  use gleam_contents <- result.try(
    simplifile.read(conf.gleam_path)
    |> result.map_error(fn(e) { GleamFileError(e) }),
  )
  use gleam_parsed <- result.try(
    tom.parse(gleam_contents)
    |> result.map_error(fn(e) { GleamParsingError(e) }),
  )

  use manifest_contents <- result.try(
    simplifile.read(conf.manifest_path)
    |> result.map_error(fn(e) { ManifestFileError(e) }),
  )
  use manifest_parsed <- result.try(
    tom.parse(manifest_contents)
    |> result.map_error(fn(e) { ManifestParsingError(e) }),
  )

  let deps =
    tom.get_table(gleam_parsed, ["dependencies"])
    |> unwrap(dict.new())
    |> filter_local_paths()
    |> dict.keys()

  let deps = case conf.include_dev {
    True -> {
      // Support deprecated syntax
      let dev_deps_deprecated =
        tom.get_table(gleam_parsed, ["dev-dependencies"])
        |> unwrap(dict.new())
        |> filter_local_paths()
        |> dict.keys()

      let dev_deps =
        tom.get_table(gleam_parsed, ["dev_dependencies"])
        |> unwrap(dict.new())
        |> filter_local_paths()
        |> dict.keys()

      list.append(deps, dev_deps)
      |> list.append(dev_deps_deprecated)
    }
    False -> deps
  }

  let deps = filter_deps(deps, conf.ignore_deps)

  let packages =
    tom.get_array(manifest_parsed, ["packages"])
    |> unwrap(list.new())
    |> list.map(fn(package) {
      case package {
        tom.InlineTable(pairs) -> {
          let assert Ok(tom.String(name)) = dict.get(pairs, "name")
          let assert Ok(tom.String(version)) = dict.get(pairs, "version")
          Some(Dependency(name:, version:))
        }
        _ -> None
      }
    })
    |> list.filter(fn(o) { option.is_some(o) })
    |> list.map(fn(o) {
      let assert Some(v) = o
      v
    })

  let result =
    list.map(deps, fn(dep) {
      let assert Ok(package) = list.find(packages, fn(p) { p.name == dep })
      Dependency(name: dep, version: package.version)
    })

  Ok(result)
}

fn filter_deps(deps: List(String), ignore: List(String)) -> List(String) {
  case ignore {
    [] -> deps
    [head, ..rest] -> {
      list.filter(deps, fn(dep) { dep != head })
      |> filter_deps(rest)
    }
  }
}
