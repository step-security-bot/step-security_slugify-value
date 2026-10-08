#!/usr/bin/env bash

if [[ "$OSTYPE" == "darwin"* ]]; then
  # On MacOS,
  # bash don't support substitution, so we use 'tr'
  KEY=$(echo "$INPUT_KEY" | tr '[:lower:]' '[:upper:]')
  CS_VALUE=${INPUT_VALUE:-${!INPUT_KEY}}
  VALUE=$(echo "$CS_VALUE" | tr '[:upper:]' '[:lower:]')
  PREFIX=$(echo "$INPUT_PREFIX" | tr '[:lower:]' '[:upper:]')
else
  KEY=${INPUT_KEY^^}
  CS_VALUE=${INPUT_VALUE:-${!INPUT_KEY}}
  VALUE=${CS_VALUE,,}
  PREFIX=${INPUT_PREFIX^^}
fi

MAX_LENGTH=""
if [ -z "${INPUT_SLUG_MAXLENGTH}" ]; then
  echo "::error ::slug-maxlength cannot be empty"
  exit 1
elif [ "${INPUT_SLUG_MAXLENGTH}" -eq "${INPUT_SLUG_MAXLENGTH}" ] 2>/dev/null; then
  MAX_LENGTH="${INPUT_SLUG_MAXLENGTH}"
elif [ "${INPUT_SLUG_MAXLENGTH}" == "nolimit" ]; then
  MAX_LENGTH="${INPUT_SLUG_MAXLENGTH}"
else
  echo "::error ::slug-maxlength must be a number or equals to 'nolimit'"
  exit 1
fi

slug() {
  # 1st : Remove refs prefix
  # 2d : Replace unwanted characters
  # 3d : Remove leading hypens
  output=$(sed -E 's#refs/[^\/]*/##;s/[^a-zA-Z0-9._-]+/-/g;s/^-*//' <<<"$1")
  reduce "$output"
}

slug_url() {
  # 1st : Remove refs prefix
  # 2d : Replace unwanted characters
  # 3d : Remove leading hypens
  output=$(sed -E 's#refs/[^\/]*/##;s/[^a-zA-Z0-9-]+/-/g;s/^-*//' <<<"$1")
  reduce "$output"
}

reduce() {
  reduced_value="$1"
  if [ "${MAX_LENGTH}" != "nolimit" ]; then
    reduced_value=$(cut -c1-"${MAX_LENGTH}" <<<"$reduced_value")
  fi
  # 1st : Remove trailing hypens
  sed -E 's/-*$//' <<<"$reduced_value"
}

SLUG_VALUE=$(slug "$VALUE")
SLUG_CS_VALUE=$(slug "$CS_VALUE")
SLUG_URL_VALUE=$(slug_url "$VALUE")
SLUG_URL_CS_VALUE=$(slug_url "$CS_VALUE")

# Write a (possibly multi-line) value using a delimiter that is not in the value,
# so untrusted input cannot inject extra name=value entries.
write_multiline() {
  local name="$1" value="$2" file="$3" delimiter
  delimiter="ghadelimiter_${RANDOM}${RANDOM}${RANDOM}${RANDOM}"
  while [[ "$value" == *"$delimiter"* ]]; do
    delimiter="ghadelimiter_${RANDOM}${RANDOM}${RANDOM}${RANDOM}"
  done
  {
    echo "${name}<<${delimiter}"
    printf '%s\n' "$value"
    echo "${delimiter}"
  } >>"$file"
}

if [ ! -f "$GITHUB_OUTPUT" ]; then
  echo "::error ::GITHUB_OUTPUT is not set or is not a file"
  exit 1
fi

write_multiline "value" "${CS_VALUE}" "$GITHUB_OUTPUT"
write_multiline "slug" "${SLUG_VALUE}" "$GITHUB_OUTPUT"
write_multiline "slug-cs" "${SLUG_CS_VALUE}" "$GITHUB_OUTPUT"
write_multiline "slug-url" "${SLUG_URL_VALUE}" "$GITHUB_OUTPUT"
write_multiline "slug-url-cs" "${SLUG_URL_CS_VALUE}" "$GITHUB_OUTPUT"

if [ "${INPUT_PUBLISH_ENV}" == "true" ]; then
  if [[ ! "${PREFIX}${KEY}" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
    echo "::error ::key and prefix must form a valid environment variable name (letters, digits and underscores)"
    exit 1
  fi
  write_multiline "${PREFIX}${KEY}" "${CS_VALUE}" "$GITHUB_ENV"
  write_multiline "${PREFIX}${KEY}_SLUG" "${SLUG_VALUE}" "$GITHUB_ENV"
  write_multiline "${PREFIX}${KEY}_SLUG_CS" "${SLUG_CS_VALUE}" "$GITHUB_ENV"
  write_multiline "${PREFIX}${KEY}_SLUG_URL" "${SLUG_URL_VALUE}" "$GITHUB_ENV"
  write_multiline "${PREFIX}${KEY}_SLUG_URL_CS" "${SLUG_URL_CS_VALUE}" "$GITHUB_ENV"
fi
