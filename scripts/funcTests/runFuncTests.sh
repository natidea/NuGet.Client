#!/usr/bin/env bash

while true ; do
    case "$1" in
        -c|--clear-cache) CLEAR_CACHE=1 ; shift ;;
        --) shift ; break ;;
        *) shift ; break ;;
    esac
done

RESULTCODE=0

# move up to the repo root
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $DIR/../../

# Download the CLI install script to cli
echo "Installing dotnet CLI"
mkdir -p cli
curl -o cli/install.sh https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/install.sh

# Run install.sh
chmod +x cli/install.sh
cli/install.sh -i cli -c beta

# Display current version
DOTNET="$(pwd)/cli/dotnet"
$DOTNET --version

echo "================="

# init the repo

git submodule init
git submodule update

# clear caches
if [ "$CLEAR_CACHE" == "1" ]
then
    # echo "Clearing the nuget cache folder"
    # rm -r -f ~/.local/share/NuGet/*

    echo "Clearing the nuget packages folder"
    rm -r -f ~/.nuget/packages/*
fi

# restore packages
$DOTNET restore src/NuGet.Core test/NuGet.Core.Tests test/NuGet.Core.FuncTests --verbosity minimal --infer-runtimes
if [ $? -ne 0 ]; then
	echo "Restore failed!!"
	exit 1
fi

# build NuGet.Shared to work around a dotnet build issue
$DOTNET build src/NuGet.Core/NuGet.Shared --framework netstandard1.5 --configuration release

# run tests
for testProject in `find test/NuGet.Core.FuncTests -type f -name project.json`
do
	testDir="$(pwd)/$(dirname $testProject)"

	if grep -q netstandardapp1.5 "$testProject"; then
		pushd $testDir

        	echo "$DOTNET test $testDir"
		$DOTNET test $testDir --configuration release --framework netstandardapp1.5

		if [ $? -ne 0 ]; then
		    echo "$testDir FAILED on CoreCLR"
		    RESULTCODE=1
		fi

		popd
	else
        	echo "Skipping the tests in $testProject on CoreCLR"
	fi
done

popd

exit $RESULTCODE
