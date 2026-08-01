#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# Avoid sandbox / leftover Bundler path overrides breaking local gems.
unset BUNDLE_PATH BUNDLE_USER_HOME GEM_SPEC_CACHE || true

# Prefer the project's conda "homepage" environment so `bash run_server.sh` works
# without manually activating Ruby first.
if [[ "${CONDA_DEFAULT_ENV:-}" != "homepage" ]]; then
  if command -v conda >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate homepage
  fi
fi

ruby_version_file="$script_dir/.ruby-version"
if [[ -f "$ruby_version_file" ]]; then
  ruby_version="$(<"$ruby_version_file")"
  ruby_bin_dir="$HOME/.rubies/ruby-$ruby_version/bin"

  if [[ -x "$ruby_bin_dir/bundle" ]]; then
    export PATH="$ruby_bin_dir:$PATH"
  fi
fi

if ! command -v bundle >/dev/null 2>&1 || ! command -v ruby >/dev/null 2>&1; then
  echo "Ruby/Bundler not found. Create the conda env first:" >&2
  echo "  conda create -y -n homepage -c conda-forge ruby=3.4" >&2
  echo "  conda install -y -n homepage -c conda-forge c-compiler cxx-compiler make pkg-config" >&2
  echo "  conda run -n homepage gem install bundler -v 4.0.9" >&2
  echo "  conda run -n homepage bundle install" >&2
  exit 127
fi

has_reload_port_arg=false
for arg in "$@"; do
  case "$arg" in
    --reload-port|--reload-port=*|--livereload-port|--livereload-port=*)
      has_reload_port_arg=true
      break
      ;;
  esac
done

extra_args=()
if [[ "$has_reload_port_arg" == false ]]; then
  reload_port="${LIVERELOAD_PORT:-35729}"

  if ! ruby -rsocket -e 'port = Integer(ARGV.fetch(0)); server = TCPServer.new("127.0.0.1", port); server.close' "$reload_port" >/dev/null 2>&1; then
    selected_port="$(ruby -rsocket -e '
      start_port = Integer(ARGV.fetch(0))
      selected_port = nil

      (start_port..start_port + 20).each do |candidate|
        begin
          server = TCPServer.new("127.0.0.1", candidate)
          server.close
          selected_port = candidate
          break
        rescue Errno::EADDRINUSE, Errno::EACCES
        end
      end

      abort("Could not find an available LiveReload port between #{start_port} and #{start_port + 20}.") unless selected_port
      puts selected_port
    ' "$reload_port")"
    echo "LiveReload port $reload_port is busy, using $selected_port instead."
    reload_port="$selected_port"
  fi

  extra_args=(--reload-port "$reload_port")
fi

exec bundle exec jekyll liveserve --host 127.0.0.1 --port 4000 "${extra_args[@]}" "$@"
