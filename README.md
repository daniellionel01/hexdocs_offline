# Hexdocs Offline

[![Package Version](https://img.shields.io/hexpm/v/hexdocs_offline)](https://hex.pm/packages/hexdocs_offline)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/hexdocs_offline/)

Download an offline version of the hexdocs of your projects dependencies to a local folder.

Useful for if you are travelling a lot and do not have a great or any internet connection at all times.
Or if you just want to have a centralized index page for all of the hexdocs of your dependencies and close 10 of those tabs.

## How?

All this package does is fetch the dependencies from the `gleam.toml` file and uses
`mix hex.docs fetch ...` to download a local version of them.

## Demo

[HEXDOCS.html](./HEXDOCS.html) for this project

## Platform Support

This package works fine on `macos` and `linux`. It has **not** been tested on Windows
and will probably fail due to the `~/.hex` directory default.

## Required Software

Apart from [Gleam](https://gleam.run/) you need to have
[Mix](https://hexdocs.pm/mix/Mix.html) installed on your system.

## Usage

### Installation
```sh
gleam add hexdocs_offline --dev
```

### Option 1: Default Config
[Example Repository](./examples/default_config)

```sh
gleam run -m hexdocs_offline
```

This will generate the hexdocs with the default configuration:
- gleam_path: `./gleam.toml`
- manifest_path: `./manifest.toml`
- output_path: `./HEXDOCS.html`
- new_tab: `True` *(opens links as a new tab)*
- include_dev: `True` *(includes dev dependencies)*
- ignore_deps: `[]` *(take all dependencies into consideration)*

### Option 2: Custom Config
[Example Repository](./examples/custom_config)

```gleam
//// file `src/dev/generate_hexdocs.gleam`

import hexdocs_offline.{generate}
import hexdocs_offline/config.{
  default_config, with_ignore_deps, with_include_dev, with_output_path,
}

pub fn main() {
  let config =
    default_config()
    |> with_output_path("./HEXDOCS.html")
    |> with_include_dev(False)
    |> with_ignore_deps(["..."])

  generate(config)
}
```

```sh
gleam run -m dev/generate_hexdocs
```

## Notices
- you might want to add the resulting `HEXDOCS.html` file to your `.gitignore`

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Acknowledgements

- Thank you `simplecss` ([GitHub](https://github.com/kevquirk/simple.css/)) (https://github.com/kevquirk)
- Thank you [Mix Docs](https://hexdocs.pm/hex/Mix.Tasks.Hex.Docs.html) for saving me a lot of pain of recreating this myself
- Thank you to `go_over` ([Hex](https://hex.pm/packages/go_over), [GitHub](https://github.com/bwireman/go-over)) for inspiring the code that reads out the `gleam.toml` file (https://github.com/bwireman)
- Thank you to `squirrel` ([Hex](https://hex.pm/packages/squirrel), [GitHub](https://github.com/giacomocavalieri/squirrel)) for a lot of the code and repository structure inspiration (https://github.com/giacomocavalieri)
