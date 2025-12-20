#!/usr/bin/env bash

# Usage: $0 [git_args]
# Lists all the actual playbooks we need to test.
# If a included task/playbook is modified, the playbooks that include it are also listed.

# Arguments:
#     git_args  Arguments for the "git diff" commands, like a commit or commit range (optional)

set -euo pipefail

# Check required packages
is_available() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "[ERROR] $1 is required!" >&2
        exit 1
    fi
}
is_available git
is_available yq

# Gets changed playbooks and tasks
git_args="$*"
# shellcheck disable=SC2086
CHANGED_PLAYBOOKS="$(git diff --name-only $git_args -- playbooks/*.yml)"
# shellcheck disable=SC2086
CHANGED_TASKS="$(git diff --name-only $git_args -- tasks/*.yml)"

# Lists included tasks in a playbook
get_included_tasks() {
    local playbook

    playbook=$1
    # "cut" removes the "../" from the task path
    yq '..
        | select(has("ansible.builtin.include_tasks") or has("include_tasks"))
        | ( .["ansible.builtin.include_tasks"] // .["include_tasks"] )
        | ..
        | select(tag == "!!str")' "$playbook" | cut -d '/' -f2-
}

# Lists imported playbooks in a playbook
get_imported_playbooks() {
    local playbook

    playbook=$1
    yq '..
        | select(has("ansible.builtin.import_playbook") or has("import_playbook"))
        | ( .["ansible.builtin.import_playbook"] // .["import_playbook"] )
        | ..
        | select(tag == "!!str")' "$playbook"
}

# Checks if a playbook include changed tasks files
uses_changed_tasks() {
    local playbook included_tasks

    playbook=$1
    included_tasks="$(get_included_tasks "$playbook")"

    for t in $included_tasks; do
        [[ $CHANGED_TASKS =~ $t ]] && return 0
    done
    return 1
}

# Checks if a playbook include changed playbooks files
uses_changed_playbooks() {
    local playbook imported_playbooks

    playbook=$1
    imported_playbooks="$(get_imported_playbooks "$playbook")"

    for pb in $imported_playbooks; do
        [[ $CHANGED_PLAYBOOKS =~ $pb ]] && return 0
    done
    return 1
}

# Remove duplicate strings and format output
remove_duplicates_and_format() {
    echo -n "$@" | tr ' ' '\n' | sort -u | xargs
}

# List playbooks that are changed or include changed tasks/playbooks
main() {
    local all_playbooks playbooks_to_test

    all_playbooks="$(find playbooks/ -name '*.yml' -type f)"
    # Only changed playbooks are included initially
    playbooks_to_test="$CHANGED_PLAYBOOKS"

    # If a playbook uses changed tasks or playbooks, it is also included in the list
    for playbook in $all_playbooks; do
        if uses_changed_tasks "$playbook" || uses_changed_playbooks "$playbook"; then
            playbooks_to_test="$playbook $playbooks_to_test"
        fi
    done

    playbooks_to_test="$(remove_duplicates_and_format "$playbooks_to_test")"
    echo "$playbooks_to_test"
}

main
