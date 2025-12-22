#!/usr/bin/env bash

# Usage: list_playbooks_to_test.sh [git_args]
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

# Lists included tasks in a playbook
get_included_tasks() {
    # "cut" removes the "../" from the task path
    yq '..
        | select(has("ansible.builtin.include_tasks") or has("include_tasks"))
        | ( .["ansible.builtin.include_tasks"] // .["include_tasks"] )
        | ..
        | select(tag == "!!str")' "$1" | cut -d '/' -f2-
}

# Lists imported playbooks in a playbook
get_imported_playbooks() {
    yq '..
        | select(has("ansible.builtin.import_playbook") or has("import_playbook"))
        | ( .["ansible.builtin.import_playbook"] // .["import_playbook"] )
        | ..
        | select(tag == "!!str")' "$1"
}

# Checks if a playbook include changed tasks files
uses_changed_tasks() {
    local included_tasks
    included_tasks="$(get_included_tasks "$1")"

    for task in $included_tasks; do
        [[ $CHANGED_TASKS =~ $task ]] && return 0
    done
    return 1
}

# Checks if a playbook include changed playbooks files
uses_changed_playbooks() {
    local imported_playbooks
    imported_playbooks="$(get_imported_playbooks "$1")"

    for playbook in $imported_playbooks; do
        [[ $CHANGED_PLAYBOOKS =~ $playbook ]] && return 0
    done
    return 1
}

# Remove duplicate strings and format output
remove_duplicates_and_format() {
    echo -n "$@" | tr ' ' '\n' | sort -u | xargs
}

# List playbooks that are changed or include changed tasks/playbooks
main() {
    local playbooks_to_test
    # Only changed playbooks are included initially
    playbooks_to_test="$CHANGED_PLAYBOOKS"

    # If a playbook uses changed tasks or playbooks, it is also included in the list
    for playbook in playbooks/*.yml; do
        if uses_changed_tasks "$playbook" || uses_changed_playbooks "$playbook"; then
            playbooks_to_test="$playbook $playbooks_to_test"
        fi
    done

    playbooks_to_test="$(remove_duplicates_and_format "$playbooks_to_test")"
    echo "$playbooks_to_test"
}

is_available git
is_available yq

# Gets changed playbooks and tasks
CHANGED_PLAYBOOKS="$(git diff --name-only "$@" -- playbooks/*.yml)"
CHANGED_TASKS="$(git diff --name-only "$@" -- tasks/*.yml)"

main
