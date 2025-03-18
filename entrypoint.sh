#!/bin/bash
set -e

# Get environment variables
SOURCE_PATH="${SOURCE_PATH:-src}"
WIKI_PATH="${WIKI_PATH:-wiki-content}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-Update documentation from Rust code}"
EXCLUDED_PATHS="${EXCLUDED_PATHS:-}"
EXTRACT_PRIVATE="${EXTRACT_PRIVATE:-false}"
MAX_DEFINITION_LINES="${MAX_DEFINITION_LINES:-50}"

# Convert excluded paths to array
IFS=',' read -ra EXCLUDED_ARRAY <<< "$EXCLUDED_PATHS"

# Create Home.md
echo "# ${GITHUB_REPOSITORY#*/} Documentation" > "${WIKI_PATH}/Home.md"
echo "" >> "${WIKI_PATH}/Home.md"
echo "This wiki contains automatically generated documentation from the Rust codebase." >> "${WIKI_PATH}/Home.md"
echo "" >> "${WIKI_PATH}/Home.md"
echo "## Modules" >> "${WIKI_PATH}/Home.md"
echo "" >> "${WIKI_PATH}/Home.md"

# Function to check if a path should be excluded
should_exclude() {
  local file="$1"
  for excluded in "${EXCLUDED_ARRAY[@]}"; do
    if [[ "$file" == *"$excluded"* ]]; then
      return 0
    fi
  done
  return 1
}

# Process all Rust files
find "$SOURCE_PATH" -name "*.rs" -type f | while read -r file; do
  # Check if file should be excluded
  if should_exclude "$file"; then
    echo "Skipping excluded file: $file"
    continue
  fi

  # Get file info
  base_name=$(basename "$file" .rs)
  dir_path=$(dirname "$file")
  
  # Create unique file name
  unique_name=$(echo "${dir_path//\//_}_${base_name}" | sed "s/^${SOURCE_PATH//\//_}_//")
  output_file="${WIKI_PATH}/${unique_name}.md"
  
  echo "Processing $file into $output_file"
  
  # Create file header
  echo "# $base_name ($dir_path)" > "$output_file"
  echo "" >> "$output_file"
  echo "Path: \`$file\`" >> "$output_file"
  echo "" >> "$output_file"
  
  # Extract module docs
  grep -n "^[[:space:]]*//!" "$file" 2>/dev/null | sed 's/^[0-9]*://g' | sed 's/\/\/![[:space:]]*//' > "$output_file.module_docs" || true
  if [ -s "$output_file.module_docs" ]; then
    echo "## Module Documentation" >> "$output_file"
    echo "" >> "$output_file"
    cat "$output_file.module_docs" >> "$output_file"
    echo "" >> "$output_file"
  fi
  rm -f "$output_file.module_docs"
  
  # Generate TOC
  echo "## Table of Contents" >> "$output_file"
  echo "" >> "$output_file"
  
  # Extract all public items for TOC
  {
    # Extract public mods
    grep -n "^[[:space:]]*pub[[:space:]]\+mod" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+mod[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public structs 
    grep -n "^[[:space:]]*pub[[:space:]]\+struct" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+struct[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public enums
    grep -n "^[[:space:]]*pub[[:space:]]\+enum" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+enum[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public traits
    grep -n "^[[:space:]]*pub[[:space:]]\+trait" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+trait[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public fns
    grep -n "^[[:space:]]*pub[[:space:]]\+fn" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+fn[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public async fns
    grep -n "^[[:space:]]*pub[[:space:]]\+async[[:space:]]\+fn" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+async[[:space:]]+fn[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public types
    grep -n "^[[:space:]]*pub[[:space:]]\+type" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+type[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
    
    # Extract public consts
    grep -n "^[[:space:]]*pub[[:space:]]\+const" "$file" 2>/dev/null | sed -E 's/^([0-9]+):.*(pub[[:space:]]+const[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true

    # If EXTRACT_PRIVATE is true, also extract private items
    if [ "$EXTRACT_PRIVATE" = "true" ]; then
      # Extract private mods (not pub)
      grep -n "^[[:space:]]*mod[[:space:]]" "$file" | grep -v "pub" 2>/dev/null | sed -E 's/^([0-9]+):.*(mod[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
      
      # Extract private structs
      grep -n "^[[:space:]]*struct[[:space:]]" "$file" | grep -v "pub" 2>/dev/null | sed -E 's/^([0-9]+):.*(struct[[:space:]]+[a-zA-Z0-9_]+).*/\1:\2/' || true
      
      # And so on for other item types...
    fi
    
  } | sort -n > "$output_file.items"
  
  # Generate TOC from items
  while read -r line_info; do
    line_num=$(echo "$line_info" | cut -d: -f1)
    item_line=$(echo "$line_info" | cut -d: -f2-)
    
    # Extract item type and name
    if [[ "$item_line" =~ pub[[:space:]]+mod[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="mod"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#mod-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ ^mod[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="mod"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name (private)](#mod-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+struct[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="struct"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#struct-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+enum[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="enum"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#enum-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+trait[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="trait"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#trait-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+async[[:space:]]+fn[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="async fn"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#async-fn-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+fn[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="fn"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#fn-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+type[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="type"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#type-${item_name})" >> "$output_file"
    elif [[ "$item_line" =~ pub[[:space:]]+const[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="const"
      item_name="${BASH_REMATCH[1]}"
      echo "* [$item_type $item_name](#const-${item_name})" >> "$output_file"
    fi
  done < "$output_file.items"
  
  echo "" >> "$output_file"
  echo "## Public Items" >> "$output_file"
  echo "" >> "$output_file"
  
  # Process all public items
  while read -r line_info; do
    line_num=$(echo "$line_info" | cut -d: -f1)
    item_line=$(echo "$line_info" | cut -d: -f2-)
    
    # Extract item type and name
    item_type=""
    item_name=""
    is_private=false
    
    if [[ "$item_line" =~ pub[[:space:]]+mod[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="mod"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ ^mod[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="mod"
      item_name="${BASH_REMATCH[1]}"
      is_private=true
    elif [[ "$item_line" =~ pub[[:space:]]+struct[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="struct"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+enum[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="enum"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+trait[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="trait"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+async[[:space:]]+fn[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="async fn"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+fn[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="fn"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+type[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="type"
      item_name="${BASH_REMATCH[1]}"
    elif [[ "$item_line" =~ pub[[:space:]]+const[[:space:]]+([a-zA-Z0-9_]+) ]]; then
      item_type="const"
      item_name="${BASH_REMATCH[1]}"
    fi
    
    if [ -n "$item_type" ] && [ -n "$item_name" ]; then
      # Add title
      if [[ "$item_type" == "async fn" ]]; then
        echo "### async fn $item_name" >> "$output_file"
      else
        if [ "$is_private" = true ]; then
          echo "### $item_type $item_name (private)" >> "$output_file"
        else
          echo "### $item_type $item_name" >> "$output_file"
        fi
      fi
      echo "" >> "$output_file"
      
      # Extract doc comments first
      doc_start=$((line_num - 1))
      doc_lines=()
      
      while [ $doc_start -gt 0 ]; do
        doc_line=$(sed -n "${doc_start}p" "$file")
        if [[ "$doc_line" =~ ^[[:space:]]*\/\/\/ ]]; then
          comment=$(echo "$doc_line" | sed 's/^[[:space:]]*\/\/\/[[:space:]]*//')
          doc_lines=("$comment" "${doc_lines[@]}")
          doc_start=$((doc_start - 1))
        elif [[ "$doc_line" =~ ^[[:space:]]*$ ]] || [[ "$doc_line" =~ ^[[:space:]]*#\[ ]]; then
          # Skip empty lines and attributes
          doc_start=$((doc_start - 1))
        else
          break
        fi
      done
      
      # EXTRACT FULL DEFINITION
      # Add Definition header and start code block
      echo "#### Definition" >> "$output_file"
      echo "" >> "$output_file"
      echo '```rust' >> "$output_file"
      
      # Get the current line (definition start)
      def_line=$(sed -n "${line_num}p" "$file")
      echo "$def_line" >> "$output_file"
      
      # Determine how to extract based on item type
      case "$item_type" in
        "mod")
          # For module, check if it has a body or just a semicolon
          if ! [[ "$def_line" =~ \;$ ]]; then
            # It has a body, extract the content
            next_line_num=$((line_num + 1))
            # Continue until we find matching closing brace
            brace_count=1
            while [ $brace_count -gt 0 ] && [ $next_line_num -le $(wc -l < "$file") ]; do
              next_line=$(sed -n "${next_line_num}p" "$file")
              echo "$next_line" >> "$output_file"
              
              # Update brace count
              open_braces=$(grep -o "{" <<< "$next_line" | wc -l)
              close_braces=$(grep -o "}" <<< "$next_line" | wc -l)
              brace_count=$((brace_count + open_braces - close_braces))
              
              next_line_num=$((next_line_num + 1))
              
              # Limit to reasonable size
              if [ $((next_line_num - line_num)) -gt "$MAX_DEFINITION_LINES" ]; then
                echo "    // ... additional module content" >> "$output_file"
                echo "}" >> "$output_file"
                break
              fi
            done
          fi
          ;;
        "struct"|"enum"|"trait")
          # These typically have a body with braces
          if ! [[ "$def_line" =~ \;$ ]]; then
            # Find the closing brace
            next_line_num=$((line_num + 1))
            # Continue until we find matching closing brace
            brace_count=$(grep -o "{" <<< "$def_line" | wc -l)
            brace_count=$((brace_count - $(grep -o "}" <<< "$def_line" | wc -l)))
            
            while [ $brace_count -gt 0 ] && [ $next_line_num -le $(wc -l < "$file") ]; do
              next_line=$(sed -n "${next_line_num}p" "$file")
              echo "$next_line" >> "$output_file"
              
              # Update brace count
              open_braces=$(grep -o "{" <<< "$next_line" | wc -l)
              close_braces=$(grep -o "}" <<< "$next_line" | wc -l)
              brace_count=$((brace_count + open_braces - close_braces))
              
              next_line_num=$((next_line_num + 1))
              
              # Limit to reasonable size
              if [ $((next_line_num - line_num)) -gt "$MAX_DEFINITION_LINES" ]; then
                echo "    // ... additional implementation" >> "$output_file"
                echo "}" >> "$output_file"
                break
              fi
            done
          fi
          ;;
        "fn"|"async fn")
          # Functions can end with a semicolon or have a body
          if ! [[ "$def_line" =~ \;$ ]]; then
            # Find the closing brace if it has a body
            next_line_num=$((line_num + 1))
            brace_found=false
            
            # If the function signature spans multiple lines
            while [ $next_line_num -le $(wc -l < "$file") ]; do
              next_line=$(sed -n "${next_line_num}p" "$file")
              echo "$next_line" >> "$output_file"
              
              # If we found a semicolon, we're done
              if [[ "$next_line" =~ \;$ ]]; then
                break
              fi
              
              # If we found an opening brace, need to find matching closing brace
              if [[ "$next_line" =~ \{$ ]]; then
                brace_found=true
                echo "    // ... function body" >> "$output_file"
                echo "}" >> "$output_file"
                break
              fi
              
              next_line_num=$((next_line_num + 1))
              
              # Limit to reasonable size
              if [ $((next_line_num - line_num)) -gt 20 ]; then
                if ! [[ "$next_line" =~ [\;\{] ]]; then
                  echo "    // ... function definition continues" >> "$output_file"
                fi
                break
              fi
            done
            
            # If we didn't find either a semicolon or a brace, make sure to terminate the function
            if [ "$brace_found" = false ]; then
              if ! [[ "$next_line" =~ \;$ ]]; then
                echo "    // ... function body" >> "$output_file"
                echo "}" >> "$output_file"
              fi
            fi
          fi
          ;;
        "type"|"const")
          # These typically end with a semicolon
          if ! [[ "$def_line" =~ \;$ ]]; then
            next_line_num=$((line_num + 1))
            
            # Continue until semicolon
            while [ $next_line_num -le $(wc -l < "$file") ]; do
              next_line=$(sed -n "${next_line_num}p" "$file")
              echo "$next_line" >> "$output_file"
              
              if [[ "$next_line" =~ \;$ ]]; then
                break
              fi
              
              next_line_num=$((next_line_num + 1))
              
              # Limit to reasonable size
              if [ $((next_line_num - line_num)) -gt 10 ]; then
                if ! [[ "$next_line" =~ \;$ ]]; then
                  echo "    // ... definition continues" >> "$output_file"
                  echo ";" >> "$output_file"
                fi
                break
              fi
            done
          fi
          ;;
      esac
      
      # Close the code block
      echo '```' >> "$output_file"
      echo "" >> "$output_file"
      
      # Process and add doc comments
      if [ ${#doc_lines[@]} -gt 0 ]; then
        echo "#### Documentation" >> "$output_file"
        echo "" >> "$output_file"
        
        # Process the documentation lines for formatting
        current_section=""
        in_section=false
        
        for doc_line in "${doc_lines[@]}"; do
          # Check for section headers
          if [[ "$doc_line" =~ ^#[[:space:]] ]]; then
            # If we were in a section, output it first
            if [ "$in_section" = true ] && [ -n "$current_section" ]; then
              echo "$current_section" >> "$output_file"
              echo "" >> "$output_file"
              current_section=""
            fi
            
            # Output header with extra # for markdown heading level
            echo "##### ${doc_line:2}" >> "$output_file"
            echo "" >> "$output_file"
            in_section=false
          # Handle list items
          elif [[ "$doc_line" =~ ^\*[[:space:]] ]]; then
            # If we were in a paragraph, output it first
            if [ "$in_section" = true ] && [ -n "$current_section" ]; then
              echo "$current_section" >> "$output_file"
              echo "" >> "$output_file"
              current_section=""
              in_section=false
            fi
            
            # Output list item directly
            echo "$doc_line" >> "$output_file"
          # Regular paragraph text
          else
            if [ "$in_section" = true ]; then
              # If continuing a paragraph, add a space instead of newline
              current_section="${current_section} ${doc_line}"
            else
              # Starting a new paragraph
              current_section="${doc_line}"
              in_section=true
            fi
          fi
        done
        
        # Output any remaining section
        if [ "$in_section" = true ] && [ -n "$current_section" ]; then
          echo "$current_section" >> "$output_file"
          echo "" >> "$output_file"
        fi
      fi
    fi
  done < "$output_file.items"
  
  # Clean up temporary files
  rm -f "$output_file.items"
  
  # Add link to Home.md
  echo "* [$unique_name](${unique_name})" >> "${WIKI_PATH}/Home.md"
done

# Setup Git for Wiki Push
if [ -n "$GITHUB_TOKEN" ]; then
  git config --global user.email "actions@github.com"
  git config --global user.name "GitHub Actions"

  # Clone Wiki Repository
  echo "Cloning wiki repository..."
  git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git" wiki-repo

  # Copy content to wiki
  echo "Copying content to wiki..."
  cp -r ${WIKI_PATH}/* wiki-repo/

  cd wiki-repo
  git add .

  # Commit if changes exist
  if git diff --staged --quiet; then
    echo "No changes to commit"
  else
    git commit -m "${COMMIT_MESSAGE} (${GITHUB_SHA:0:7})"
    git push
    echo "Wiki successfully updated!"
  fi
else
  echo "GITHUB_TOKEN not provided, skipping wiki push"
  echo "Generated documentation is available in the ${WIKI_PATH} directory"
fi
