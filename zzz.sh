#! /bin/env bash
local dry_run=0
local help=0
local automatic=0
local commit_msg=""
while [ $# -gt 0 ]
do
	case "$1" in
		(--help | -h) help=1
			dry_run=1
			shift ;;
		(--dry-run | -n) dry_run=1
			shift ;;
		(--auto | -a) automatic=1
			shift ;;
		(*) commit_msg="$1"
			shift ;;
	esac
done
if [ -z "$commit_msg" ]
then
	commit_msg="Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
fi
local repos=()
if [ -e "./cmake/.git" ]
then
	repos+=("./cmake")
fi
for dir in ./*/cmake
do
	if [ -e "$dir/.git" ]
	then
		repos+=("$dir")
	fi
done
if [ $dry_run -eq 1 ]
then
	printf "🔍 DRY RUN MODE - No changes will be made\n"
	echo ""
fi
if [ $help -eq 1 ]
then
	echo "🔍 Usage:  seemake [--dry-run | -n] [--auto | -a] [\"Commit message\"]"
	echo ""
	echo "           --dry-run | -n   : Dry run - no data will be changed"
	echo "           --auto    | -a   : Automatic push - don't ask, just do it"
	echo "           \"Commit message\" : Optional commit message"
	echo ""
	return 0
fi
if [ ${#repos[@]} -eq 0 ]
then
	echo "❌ No git repositories found"
	return 1
fi
echo "Found ${#repos[@]} repositories to sync"
echo "Commit message: $commit_msg"
echo ""
declare -A repos_with_changes
echo "Checking for uncommitted changes..."
local changes_found=0
for repo in "${repos[@]}"
do
	if [ -e "$repo/.git" ]
	then
		cd "$repo" || continue
		if ! git diff-index --quiet HEAD -- 2> /dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]
		then
			echo "📝 Uncommitted changes in: $repo"
			changes_found=1
			repos_with_changes[$repo]=1
			if [ $dry_run -eq 1 ]
			then
				echo "   Would commit with message: $commit_msg"
				git status --short
			else
				echo "   Committing changes..."
				git add -A
				git commit -m "$commit_msg" || echo "  ⚠️  Commit failed"
			fi
		fi
		cd - > /dev/null
	fi
done
if [ $changes_found -eq 0 ]
then
	echo "No uncommitted changes found"
else
	echo ""
	if [ $dry_run -eq 1 ]
	then
		echo "⚠️  WARNING: Uncommitted changes detected in ${#repos_with_changes[@]} repo(s)"
		echo "   In a real run, these would be committed BEFORE syncing."
		echo "   This means each repo's uncommitted changes would become separate commits."
		echo "   After sync, all repos would have ALL of these commits merged together."
		echo ""
	fi
fi
echo "Fetching from remotes..."
for repo in "${repos[@]}"
do
	if [ -e "$repo/.git" ]
	then
		cd "$repo" || continue
		if [ $dry_run -eq 1 ]
		then
			echo "Would fetch: $repo"
		else
			git fetch --all --prune 2> /dev/null
		fi
		cd - > /dev/null
	fi
done
echo ""
echo "Determining most recent state..."
local max_commit_date=0
local reference_repo=""
local branch_name=""
for repo in "${repos[@]}"
do
	if [ -e "$repo/.git" ]
	then
		cd "$repo" || continue
		local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		local commit_date=$(git log -1 --format=%ct 2>/dev/null)
		local commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
		local commit_subject=$(git log -1 --format=%s 2>/dev/null)
		local display_note=""
		if [ $dry_run -eq 1 ] && [ "${repos_with_changes[$repo]}" = "1" ]
		then
			display_note=" (+ uncommitted → would be newer after commit)"
			commit_date=$((commit_date + 1))
		fi
		echo "  $repo: $commit_hash - $commit_subject ($(date -d @$commit_date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $commit_date '+%Y-%m-%d %H:%M:%S' 2>/dev/null))$display_note"
		if [ -n "$commit_date" ] && [ "$commit_date" -gt "$max_commit_date" ]
		then
			max_commit_date=$commit_date
			reference_repo=$repo
			branch_name=$current_branch
		fi
		cd - > /dev/null
	fi
done
if [ -z "$reference_repo" ]
then
	echo "❌ Could not determine reference repository"
	return 1
fi
echo ""
echo "📌 Using $reference_repo (branch: $branch_name) as reference"
cd "$reference_repo" || return 1
local reference_repo_abs=$(pwd)
local reference_commit=$(git rev-parse --short HEAD)
cd - > /dev/null
echo "   Reference commit: $reference_commit"
if [ $dry_run -eq 1 ] && [ "${repos_with_changes[$reference_repo]}" = "1" ]
then
	echo "   (Note: Reference has uncommitted changes that would be committed first)"
fi
echo ""
echo "Analyzing sync requirements..."
local sync_needed=0
for repo in "${repos[@]}"
do
	if [ "$repo" = "$reference_repo" ]
	then
		continue
	fi
	if [ -e "$repo/.git" ]
	then
		cd "$repo" || continue
		local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		local current_commit=$(git rev-parse --short HEAD 2>/dev/null)
		if [ "$current_branch" != "$branch_name" ]
		then
			echo "⚠️  $repo is on branch '$current_branch', needs to switch to '$branch_name'"
			sync_needed=1
		fi
		local needs_sync=0
		if [ "${repos_with_changes[$repo]}" = "1" ] || [ "${repos_with_changes[$reference_repo]}" = "1" ]
		then
			needs_sync=1
		elif [ "$current_commit" != "$reference_commit" ]
		then
			needs_sync=1
		fi
		if [ $needs_sync -eq 1 ]
		then
			echo "🔄 $repo needs sync:"
			echo "   Current: $current_commit"
			echo "   Target:  $reference_commit (from $reference_repo)"
			if [ $dry_run -eq 1 ]
			then
				if [ "${repos_with_changes[$repo]}" = "1" ] && [ "${repos_with_changes[$reference_repo]}" = "1" ]
				then
					echo "   ⚠️  Both repos have uncommitted changes"
					echo "      After committing, both would have new (different) commits"
					echo "      Merge would be required - you'll be prompted to resolve conflicts"
				elif [ "${repos_with_changes[$repo]}" = "1" ]
				then
					echo "   📝 This repo has uncommitted changes"
					echo "      After committing, would need to merge reference repo's commits"
				elif [ "${repos_with_changes[$reference_repo]}" = "1" ]
				then
					echo "   📝 Reference repo has uncommitted changes"
					echo "      After reference commits, this repo would need to pull those changes"
				fi
			else
				git remote add _sync_temp_check "file://$reference_repo_abs" 2> /dev/null || git remote set-url _sync_temp_check "file://$reference_repo_abs"
				git fetch _sync_temp_check 2> /dev/null
				local ahead_behind=$(git rev-list --left-right --count HEAD..._sync_temp_check/"$branch_name" 2>/dev/null)
				if [ -n "$ahead_behind" ]
				then
					local ahead=$(echo "$ahead_behind" | awk '{print $1}')
					local behind=$(echo "$ahead_behind" | awk '{print $2}')
					if [ -n "$ahead" ] && [ "$ahead" -gt 0 ]
					then
						echo "   📊 $ahead commits ahead of reference"
					fi
					if [ -n "$behind" ] && [ "$behind" -gt 0 ]
					then
						echo "   📊 $behind commits behind reference"
					fi
					if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] && [ -n "$behind" ] && [ "$behind" -gt 0 ]
					then
						echo "   🔀 Merge required (branches have diverged)"
					fi
				fi
				local merge_base=$(git merge-base HEAD _sync_temp_check/"$branch_name" 2>/dev/null)
				if [ -n "$merge_base" ]
				then
					local files_diff_here=$(git diff --name-only "$merge_base" HEAD 2>/dev/null | sort)
					local files_diff_there=$(git diff --name-only "$merge_base" _sync_temp_check/"$branch_name" 2>/dev/null | sort)
					if [ -n "$files_diff_here" ] && [ -n "$files_diff_there" ]
					then
						local common_files=$(comm -12 <(echo "$files_diff_here") <(echo "$files_diff_there") 2>/dev/null | wc -l)
						if [ "$common_files" -gt 0 ]
						then
							echo "   ⚠️  WARNING: $common_files file(s) modified in both branches"
							echo "      You'll be prompted to resolve conflicts manually"
						else
							echo "   ✅ No overlapping file changes - clean merge expected"
						fi
					else
						echo "   ✅ No merge conflicts expected"
					fi
				fi
				git remote remove _sync_temp_check 2> /dev/null
			fi
			sync_needed=1
		else
			echo "✅ $repo is already in sync"
		fi
		cd - > /dev/null
	fi
done
if [ $sync_needed -eq 0 ]
then
	echo ""
	echo "✅ All repositories are already in sync!"
	return 0
fi
if [ $dry_run -eq 1 ]
then
	echo ""
	echo "🔍 DRY RUN COMPLETE - No changes were made"
	echo ""
	echo "What will happen in a real run:"
	echo "1. All uncommitted changes will be committed in each repo"
	echo "2. Repos will be synced by merging with: $reference_repo"
	echo "3. If merge conflicts occur, your editor will open for manual resolution"
	echo "4. All repos will end up with all commits from all repos"
	return 0
fi
echo ""
echo "Synchronizing repositories..."
local had_conflicts=0
for repo in "${repos[@]}"
do
	if [ "$repo" = "$reference_repo" ]
	then
		echo "Skipping reference repo: $repo"
		continue
	fi
	if [ -e "$repo/.git" ]
	then
		echo "Syncing: $repo"
		cd "$repo" || continue
		local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
		if [ "$current_branch" != "$branch_name" ]
		then
			git checkout "$branch_name" 2> /dev/null || {
				echo "  ⚠️  Could not checkout $branch_name, skipping"
				cd - > /dev/null
				continue
			}
		fi
		git remote add _sync_temp "file://$reference_repo_abs" 2> /dev/null || git remote set-url _sync_temp "file://$reference_repo_abs"
		git fetch _sync_temp 2> /dev/null
		echo "  Attempting merge..."
		git merge _sync_temp/"$branch_name" -m "Sync from $reference_repo" 2>&1
		local unmerged_count=$(git ls-files -u | wc -l)
		if [ "$unmerged_count" -gt 0 ]
		then
			echo ""
			echo "  ⚠️  Merge conflicts detected!"
			echo "  Conflicted files:"
			git diff --name-only --diff-filter=U | sed 's/^/    - /'
			echo ""
			echo "  Opening editor to resolve conflicts..."
			echo "  Please resolve conflicts, save, and close the editor to continue."
			echo "  (Or press Ctrl+C to abort the sync)"
			echo ""
			local editor="${EDITOR:-${VISUAL:-vi}}"
			local conflicted_files=$(git diff --name-only --diff-filter=U)
			if [ -n "$conflicted_files" ]
			then
				$editor $conflicted_files
				echo ""
				echo "  Checking if conflicts are resolved..."
				unmerged_count=$(git ls-files -u | wc -l)
				if [ "$unmerged_count" -gt 0 ]
				then
					echo "  ❌ Conflicts still remain. Please resolve manually:"
					git status --short
					echo ""
					read -p "  Have you resolved all conflicts? (y/N): " -n 1 -r
					echo
					if [[ ! $REPLY =~ ^[Yy]$ ]]
					then
						echo "  Aborting merge for $repo"
						git merge --abort
						cd - > /dev/null
						continue
					fi
				fi
				echo "  Staging resolved files..."
				git add -A
				if git commit --no-edit 2> /dev/null
				then
					echo "  ✅ Conflicts resolved and committed"
				else
					echo "  ✅ Merge completed"
				fi
				had_conflicts=1
			fi
		else
			echo "  ✅ Merged successfully"
		fi
		git remote remove _sync_temp 2> /dev/null
		cd - > /dev/null
	fi
done
if [ $had_conflicts -eq 1 ]
then
	echo ""
	echo "🔄 Conflicts were resolved. Re-checking sync state..."
	echo ""
	for repo in "${repos[@]}"
	do
		if [ -e "$repo/.git" ]
		then
			cd "$repo" || continue
			local current_commit=$(git rev-parse --short HEAD 2>/dev/null)
			echo "  $repo: $current_commit"
			cd - > /dev/null
		fi
	done
fi
if [ $automatic -eq 1 ]
then
	REPLY=Y
else
	echo ""
	read -p "Push all repositories to their remotes? (y/N): " -n 1 -r
	echo
fi
if [[ $REPLY =~ ^[Yy]$ ]]
then
	for repo in "${repos[@]}"
	do
		if [ -e "$repo/.git" ]
		then
			cd "$repo" || continue
			if git remote | grep --color=auto -q .
			then
				echo "Pushing: $repo"
				if git push 2>&1
				then
					echo "  ✅ Pushed successfully"
				else
					echo "  ⚠️  Push failed"
				fi
			else
				echo "Skipping $repo (no remote configured)"
			fi
			cd - > /dev/null
		fi
	done
fi
echo ""
echo "✅ Synchronization complete!"

