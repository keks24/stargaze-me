#!/bin/bash
# global
repository_name="stargaze-me"
username="ramon"
home_directory="/home/${username}"
token_directory="${home_directory}/.local/etc/${repository_name}/tokens"
token_filename_suffix="token"
profile_username="keks24"
protocol_type="https"
repository_urls_file="to_be_starred"
user_urls_file="to_be_followed"
declare -a repository_name_array
repository_name_array=
declare -a user_name_array
user_name=
http_response_code_get=
http_response_code_put=
# github.com
github_url="https://github.com"
github_username="${profile_username}"
github_token_filename="${github_url/https:\/\//}.${token_filename_suffix}"
github_token=$(< "${token_directory}/${github_token_filename}")

# star a repository
if [[ -f "${repository_urls_file}" ]]
then
    if [[ $(< "${repository_urls_file}") == "" ]]
    then
        echo -e "\e[01;31mThe file '${repository_urls_file}' is empty. Nothing to do...\e[0m" >&2
    fi

    # remove "https://github.com/" from each line. using a "look-behind" regular
    # expression is very inefficient.
    # the trailing slash is important!
    # for example: keep "kgsws/doom-in-doom" from "https://github.com/kgsws/doom-in-doom"
    repository_name_array=($(/bin/sed "s;${github_url}/;;g" "${repository_urls_file}"))

    # check, if the repository is starred already.
    ## https://docs.github.com/en/rest/activity/starring#check-if-a-repository-is-starred-by-the-authenticated-user
    ## http response codes
    ### 204 response if this repository is starred by you
    ### 304 not modified
    ### 401 requires authentication
    ### 403 forbidden
    ### 404 not found if this repository is not starred by you

    for repository_name in "${repository_name_array[@]}"
    do
        echo -ne "\e[01;34mStarring repository '${github_url}/${repository_name}'... \e[0m"

        http_response_code_get=$(/usr/bin/curl \
            --silent \
            --show-error \
            --output "/dev/null" \
            --write-out "%{http_code}" \
            --request GET \
            --header "Accept: application/vnd.github+json" \
            --header "Authorization: token ${github_token}" \
            "https://api.github.com/user/starred/${repository_name}" 2>&1)

        case "${http_response_code_get}" in
            "204")
                echo -e "\e[01;33malready starred.\e[0m"
                http_response_code_get=
                ;;

            # not starred yet.
            "404")
                # star the given repository.
                ## https://docs.github.com/en/rest/activity/starring#star-a-repository-for-the-authenticated-user
                ### 204 no content (repository successfully starred)
                ### 304 not modified
                ### 401 requires authentication
                ### 403 forbidden
                ### 404 resource not found

                http_response_code_get=
                http_response_code_put=$(/usr/bin/curl \
                    --silent \
                    --show-error \
                    --output "/dev/null" \
                    --write-out "%{http_code}" \
                    --request PUT \
                    --header "Content-Length: 0" \
                    --header "Accept: application/vnd.github+json" \
                    --header "Authorization: token ${github_token}" \
                    "https://api.github.com/user/starred/${repository_name}" 2>&1)

                case "${http_response_code_put}" in
                    "204")
                        http_response_code_put=
                        echo -e "\e[01;32msuccess!\e[0m"
                        continue
                        ;;

                    "304")
                        http_response_code_put=
                        echo -e "\e[01;33mHTTP response '${http_response_code_put}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Not modified.\e[0m" >&2
                        ;;

                    "401")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Authentication required!\e[0m" >&2
                        ;;

                    "403")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Forbidden.\e[0m" >&2
                        ;;

                    "404")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Resource not found.\e[0m" >&2
                        ;;

                    *)
                        echo -e "\e[01;31mSomething went wrong. HTTP response '${http_response_code_put}', repository '${github_url}/${repository_name}', profile username '${profile_username}'.\e[0m" >&2
                        exit 1
                esac
                ;;

            "304")
                echo -e "\e[01;33mHTTP response '${http_response_code_get}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Not modified.\e[0m" >&2
                http_response_code_get=
                ;;

            "401")
                echo -e "\e[01;31mHTTP response '${http_response_code_get}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Authentication required!\e[0m" >&2
                http_response_code_get=
                ;;

            "403")
                echo -e "\e[01;31mHTTP response '${http_response_code_get}', repository '${github_url}/${repository_name}', profile username '${profile_username}': Forbidden.\e[0m" >&2
                http_response_code_get=
                ;;

            *)
                echo -e "\e[01;31mSomething went wrong. HTTP response '${http_response_code_get}', repository '${github_url}/${repository_name}', profile username '${profile_username}'.\e[0m" >&2
                exit 1
        esac
    done
else
    echo -e "\e[01;31mCould not find file: '${repository_urls_file}'." >&2
    exit 1
fi

# follow a user
if [[ -f "${user_urls_file}" ]]
then
    if [[ $(< "${user_urls_file}") == "" ]]
    then
        echo -e "\e[01;31mThe file '${user_urls_file}' is empty. Nothing to do...\e[0m" >&2
    fi

    # remove "https://github.com/" from each line. using a "look-behind" regular
    # expression is very inefficient.
    # the trailing slash is important!
    # for example: keep "kgsws" from "https://github.com/kgsws"
    user_name_array=($(/bin/sed "s;${github_url}/;;g" "${user_urls_file}"))

    # check, if the user is followed already.
    ## https://docs.github.com/en/rest/users/followers#follow-a-user
    ## http response codes
    ### 204 if the person is followed by the authenticated user
    ### 304 Not modified
    ### 401 Requires authentication
    ### 403 Forbidden
    ### 404 if the person is not followed by the authenticated user

    for user_name in "${user_name_array[@]}"
    do
        echo -ne "\e[01;35mFollowing user '${github_url}/${user_name}'... \e[0m"

        http_response_code_get=$(/usr/bin/curl \
            --silent \
            --show-error \
            --output "/dev/null" \
            --write-out "%{http_code}" \
            --request GET \
            --header "Accept: application/vnd.github+json" \
            --header "Authorization: token ${github_token}" \
            "https://api.github.com/user/following/${user_name}" 2>&1)

        case "${http_response_code_get}" in
            "204")
                echo -e "\e[01;33malready following.\e[0m"
                http_response_code_get=
                ;;

            # not followed yet.
            "404")
                # follow the given user.
                ## https://docs.github.com/en/rest/users/followers#follow-a-user
                ### 204 no content (user successfully followed)
                ### 304 not modified
                ### 401 requires authentication
                ### 403 forbidden
                ### 404 resource not found

                http_response_code_get=
                http_response_code_put=$(/usr/bin/curl \
                    --silent \
                    --show-error \
                    --output "/dev/null" \
                    --write-out "%{http_code}" \
                    --request PUT \
                    --header "Content-Length: 0" \
                    --header "Accept: application/vnd.github+json" \
                    --header "Authorization: token ${github_token}" \
                    "https://api.github.com/user/following/${user_name}" 2>&1)

                case "${http_response_code_put}" in
                    "204")
                        http_response_code_put=
                        echo -e "\e[01;32msuccess!\e[0m"
                        continue
                        ;;

                    "304")
                        http_response_code_put=
                        echo -e "\e[01;33mHTTP response '${http_response_code_put}', user '${github_url}/${user_name}', profile username '${profile_username}': Not modified.\e[0m" >&2
                        ;;

                    "401")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', user '${github_url}/${user_name}', profile username '${profile_username}': Authentication required!\e[0m" >&2
                        ;;

                    "403")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', user '${github_url}/${user_name}', profile username '${profile_username}': Forbidden.\e[0m" >&2
                        ;;

                    "404")
                        http_response_code_put=
                        echo -e "\e[01;31mHTTP response '${http_response_code_put}', user '${github_url}/${user_name}', profile username '${profile_username}': Resource not found.\e[0m" >&2
                        ;;

                    *)
                        echo -e "\e[01;31mSomething went wrong. HTTP response '${http_response_code_put}', user '${github_url}/${user_name}', profile username '${profile_username}'.\e[0m" >&2
                        exit 1
                esac
                ;;

            "304")
                echo -e "\e[01;33mHTTP response '${http_response_code_get}', user '${github_url}/${user_name}', profile username '${profile_username}': Not modified.\e[0m" >&2
                http_response_code_get=
                ;;

            "401")
                echo -e "\e[01;31mHTTP response '${http_response_code_get}', user '${github_url}/${user_name}', profile username '${profile_username}': Authentication required!\e[0m" >&2
                http_response_code_get=
                ;;

            "403")
                echo -e "\e[01;31mHTTP response '${http_response_code_get}', user '${github_url}/${user_name}', profile username '${profile_username}': Forbidden.\e[0m" >&2
                http_response_code_get=
                ;;

            *)
                echo -e "\e[01;31mSomething went wrong. HTTP response '${http_response_code_get}', user '${github_url}/${user_name}', profile username '${profile_username}'.\e[0m" >&2
                exit 1
        esac
    done
else
    echo -e "\e[01;31mCould not find file: '${user_urls_file}'." >&2
    exit 1
fi
