#!/bin/bash

BUNDLES=(
    "pimcore"
    "admin-ui-classic-bundle"
    "data-hub"
    "data-importer"
    "perspective-editor"
    "advanced-object-search"
    "web-to-print-bundle"
    "system-info-bundle"
    "file-explorer-bundle"
    "pimcore-docs"
)

if [ -f "pimcore-contribute-assistant.env" ]; then
    source pimcore-contribute-assistant.env
fi

if [ -z "$PIMCORE_ROOT" ]; then
    printf 'Enter the absolute path to you pimcore root folder (e.g. "/var/www/html/"): '
    read PIMCORE_ROOT
fi

cd $PIMCORE_ROOT

if [ -z "$BUNDLE_BLOCKLIST" ]; then
    BUNDLE_BLOCKLIST="(docker|skeleton|demo|github|example|payment|elasticsearch|search-query-parser|personalized-product-search|number-sequence-generator|test-|s3-pit)"
fi

if grep -q "repositories" composer.json || grep -q "minimum-stability" composer.json; then
    echo 'WARNING: Please remove the "minimum-stability" and "repositories" setting from the composer.json file if you want to apply new changes!'
fi

if [ -z "$GITHUB_USERNAME" ]; then
    printf 'What is you github username? '
    read GITHUB_USERNAME
fi

if [ -z "$COMPOSER_EXECUTOR" ]; then
    printf 'Enter the composer executor (e.q. "docker compose exec php composer" or just "composer"): '
    read COMPOSER_EXECUTOR
fi

printf 'Do you want to fetch all pimcore repositories from github (a) or preferred offline list (p)? '
read FETCH_REPOSITORIES

if [ "$FETCH_REPOSITORIES" != "${FETCH_REPOSITORIES#[Aa]}" ] ;then
    if [ -z "$GITHUB_API_TOKEN" ]; then
        printf 'Enter you github api token (access to: repo, delete_repo)? '
        read GITHUB_API_TOKEN
    fi

    BUNDLES=()
    ARCHIVED_REPOSITORIES="(composer-installer-core|composer-installer-plugin|example-plugin|composer-installer-areabrick|example-areabrick|composer-installer-website-component|core-version|demo-ecommerce|pimcore4-compatibility-bridge|pimcore-cli|webinar-code-samples|pimcore4-shims|pimcore-api-docs|server-side-matomo-tracking|demo-basic|demo-basic-twig|pimcore-issue-13984)"

    if command -v jq >/dev/null 2>&1; then
        ARCHIVED_REPOSITORIES="("$(curl -s https://api.github.com/orgs/pimcore/repos?per_page=200 | jq -r '[.[] | select(.archived == true) | .name] | join("|")')")"
    fi

    FETCHED_BUNDLE_LIST=$(curl -sL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_API_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/orgs/pimcore/repos?per_page=200 | grep "full_name" | grep -vE $BUNDLE_BLOCKLIST | grep -vE $ARCHIVED_REPOSITORIES | awk -F '"' '{ gsub("pimcore/" , "", $4); print $4 }'
    )

    while IFS= read -r BUNDLE; do
        BUNDLES+=("$BUNDLE")
    done <<< "$FETCHED_BUNDLE_LIST"
fi

FILTERED_BUNDLES=()

for BUNDLE in "${BUNDLES[@]}"; do
    if [ -z "$BUNDLE_ALLOWLIST" ] || echo $BUNDLE | grep -Eq "$BUNDLE_ALLOWLIST"; then
        FILTERED_BUNDLES+=("$BUNDLE")
    fi
done

BUNDLES=("${FILTERED_BUNDLES[@]}")
FILTERED_BUNDLES=()

for BUNDLE in "${BUNDLES[@]}"; do
    if [ -z "$BUNDLE_BLOCKLIST" ] || echo $BUNDLE | grep -Evq "$BUNDLE_BLOCKLIST"; then
        FILTERED_BUNDLES+=("$BUNDLE")
    fi
done

BUNDLES=("${FILTERED_BUNDLES[@]}")

printf 'Do you want to fork repositories in github (y/n)? '
read CREATE_FORKS

if [ "$CREATE_FORKS" != "${CREATE_FORKS#[Yy]}" ] ;then
    printf 'Would you like to delete & recreate some selected repos if exists in github? (y/n)'
    read ASK_FOR_DELETE

    if [ -z "$FORK_DEFAULT_BRANCH_ONLY" ]; then
        printf 'Do you want to fork the default branch only (not recommended for bug fixes)? (y/n)'
        read FORK_DEFAULT_BRANCH_ONLY
    fi

    for BUNDLE in "${BUNDLES[@]}"; do
        if [ "$ASK_FOR_DELETE" != "${ASK_FOR_DELETE#[Yy]}" ] ;then
            printf "\n"
            printf $GITHUB_USERNAME'/pimcore-'$BUNDLE': Would you like to delete this repo if it exists (enter fullname to delete, press enter to skip)? '
            read SHOULD_DELETE_REPO

            if [ "$SHOULD_DELETE_REPO" = "$GITHUB_USERNAME/pimcore-$BUNDLE" ]; then
                if [ -z "$GITHUB_API_TOKEN" ]; then
                    printf 'Enter you github api token (access to: repo, delete_repo)? '
                    read GITHUB_API_TOKEN
                fi

                printf "$GITHUB_USERNAME/pimcore-$BUNDLE: Deletion confirmed.\n"

                curl -sL \
                    --output /dev/null \
                    -X DELETE \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer $GITHUB_API_TOKEN" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/$GITHUB_USERNAME/pimcore-$BUNDLE

                sleep 1
            else
                printf "$GITHUB_USERNAME/pimcore-$BUNDLE: Deletion rejected.\n"
            fi
        fi

        if [ "$FORK_DEFAULT_BRANCH_ONLY" != "${FORK_DEFAULT_BRANCH_ONLY#[Yy]}" ] ;then
            curl -sL \
                --output /dev/null \
                -X POST \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $GITHUB_API_TOKEN" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                https://api.github.com/repos/pimcore/$BUNDLE/forks \
                -d '{"name":"pimcore-'$BUNDLE'","repo":"pimcore-'$BUNDLE'","owner":"'$GITHUB_USERNAME'","default_branch_only":true}'
        else
            curl -sL \
                --output /dev/null \
                -X POST \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $GITHUB_API_TOKEN" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                https://api.github.com/repos/pimcore/$BUNDLE/forks \
                -d '{"name":"pimcore-'$BUNDLE'","repo":"pimcore-'$BUNDLE'","owner":"'$GITHUB_USERNAME'","default_branch_only":false}'
        fi

        printf "$GITHUB_USERNAME/pimcore-$BUNDLE: Fork created (if not exist before).\n"
        sleep 1
    done

    printf "\nNow there is a 30-second wait, as the forks are created asynchronously. Time to grab a cup of coffee or tea :-)\n"
    sleep 30
fi

printf "Cloning repositories into \"$PIMCORE_ROOT/bundles/\"...\n"

if ! [[ -e "bundles/" ]]; then
    mkdir bundles/
fi

COMPOSER_REPOSITORIES="\"repositories\":["

for BUNDLE in "${BUNDLES[@]}"; do
    if ! [[ -e "bundles/$BUNDLE" ]]; then
        git clone git@github.com:$GITHUB_USERNAME/pimcore-$BUNDLE.git bundles/$BUNDLE
    fi

    if ! [[ -e "bundles/$BUNDLE" ]]; then
        git clone git@github.com:pimcore/$BUNDLE.git bundles/$BUNDLE
        printf "$GITHUB_USERNAME/pimcore-$BUNDLE: Could not found as fork. Instead a clone from pimcore will use.\n"
    else
        printf "$GITHUB_USERNAME/pimcore-$BUNDLE: Clone created.\n"
    fi

    COMPOSER_REPOSITORIES="$COMPOSER_REPOSITORIES{\"type\":\"path\",\"url\":\"bundles/$BUNDLE\"},"
done

COMPOSER_REPOSITORIES="`echo $COMPOSER_REPOSITORIES | awk '{print substr($1, 0, length($1) - 1)}'`],"

if ! grep -q "repositories" composer.json; then
    cp composer.json composer.json-`date +%Y-%m-%d-%H-%M-%S`
    cp composer.lock composer.lock-`date +%Y-%m-%d-%H-%M-%S`

    sed -i "/\"prefer-stable\":/a $COMPOSER_REPOSITORIES" composer.json
    sed -i "/\"prefer-stable\":/a \"minimum-stability\":\"dev\"," composer.json
else
    printf "\n"
    printf 'WARNING: composer.json changes could not be included automatically.\n'
    printf 'WARNING: Please remove the "minimum-stability" and "repositories" setting from the composer.json file and run the script again or megre it manually:\n'
    printf 'WARNING:   - set "minimum-stability" to "dev"\n'
    printf 'WARNING:   - set "repositories" to: '$COMPOSER_REPOSITORIES'\n'
fi

$COMPOSER_EXECUTOR install --no-scripts

for BUNDLE in "${BUNDLES[@]}"; do
    printf "\n"
    printf $GITHUB_USERNAME'/pimcore-'$BUNDLE': Would you like to req this by composer (y/n)? '
    read REQ_BY_COMPOSER

    if [ "$REQ_BY_COMPOSER" != "${REQ_BY_COMPOSER#[Yy]}" ] ;then
        if ! grep -F '"pimcore/'$BUNDLE'"' bundles/$BUNDLE/composer.json; then
            BUNDLE="$BUNDLE-bundle"
        fi

        $COMPOSER_EXECUTOR req pimcore/$BUNDLE:"@dev" --no-scripts
    fi
done

$COMPOSER_EXECUTOR install
