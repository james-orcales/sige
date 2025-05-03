package main


import "core:io"
import "core:os"
import "core:strings"


UPDATE_ALL :: false
files_to_update := make(map[string]int)


Snapshot :: struct {
        expected:   string,
        file_path:  string,
        source:     []byte `fmt:"s"`,
        start, end: int,
        update:     bool,
}


snap :: proc(
        test_input: string,
        update := false,
        loc := #caller_location,
        allocator := context.temp_allocator,
) -> Snapshot {
        context.allocator = context.temp_allocator
        source :=
                os.read_entire_file(loc.file_path) or_else panic(
                        "snapshot.snap: couldn't read file",
                )
        start, end := find_snap_range(
                string(source),
                int(loc.line) + files_to_update[loc.file_path],
        )
        return {
                expected = test_input,
                file_path = loc.file_path,
                source = source,
                start = start,
                end = end,
                update = update || UPDATE_ALL,
        }
}


diff :: proc(actual: string, want: Snapshot, allocator := context.temp_allocator) -> Error {
        context.allocator = allocator
        str_new, newlines, err := diff_string(actual, want)
        files_to_update[want.file_path] += newlines
        defer delete(str_new)
        if err == .SnapshotUpdated {
                os.write_entire_file_or_err(want.file_path, transmute([]byte)str_new) or_return
        }
        return err
}


// caller owns the returned string
diff_string :: proc(
        actual: string,
        want: Snapshot,
        allocator := context.allocator,
) -> (
        new_src: string,
        newlines: int,
        err: Error_General,
) {
        context.allocator = allocator
        if want.expected == actual {return}
        err = .SnapshotMismatch
        if !want.update {return}


        sb := new(strings.Builder)
        strings.builder_init(sb, 0, len(want.source))
        strings.write_string(sb, string(want.source[:want.start + len("snap(")]))
        strings.write_byte(sb, '`')
        strings.write_string(sb, actual)
        strings.write_string(sb, "`)")
        new_end := strings.builder_len(sb^)
        strings.write_string(sb, string(want.source[want.end:]))


        str := strings.to_string(sb^)
        new_newlines := strings.count(str[want.start:new_end], "\n")
        old_newlines := strings.count(string(want.source[want.start:want.end]), "\n")


        return str, new_newlines - old_newlines, .SnapshotUpdated
}


// finds the snap callsite byte range starting from the identifier up to its closing parenthesis (exclusive)
@(private)
find_snap_range :: proc(
        src: string,
        line: int,
        allocator := context.allocator,
) -> (
        start, end: int,
) {
        context.allocator = allocator
        if len(src) == 0 {
                return
        }
        line_start, line_end: Maybe(int)
        {
                defer {
                        assert(
                                !(line_start != nil && line_end == nil),
                                "the snap callsite should be impossible to be at the last line of the file",
                        )
                        assert(line_start != nil, "Target line not found in src")
                }
                current_line := 1 // (1-indexed)
                for grapheme, pos in src {
                        if current_line < line {
                                if grapheme == '\n' {
                                        current_line += 1
                                }
                                continue
                        }
                        if line_start == nil {
                                line_start = pos
                        }
                        if grapheme == '\n' {
                                line_end = pos
                                break
                        }
                }
        }
        seen_string_open, string_terminated: bool
        defer assert(
                seen_string_open && string_terminated && true,
                "snapshot expected output must be hardcoded with string literals",
        )
        start = line_start.(int) + strings.index(src[line_start.(int):line_end.(int)], "snap(")
        assert(start >= 0, "did not find snap in the line")
        for ch, i in src[start:] {
                if ch == ')' && seen_string_open && string_terminated {
                        end = start + i + 1
                        break
                }
                if ch != '`' && ch != '"' {continue}
                string_terminated = seen_string_open
                seen_string_open = true
        }
        return
}


Error :: union #shared_nil {
        Error_General,
        os.Error,
        io.Error,
}


Error_General :: enum {
        SnapshotMatched,
        SnapshotMismatch,
        SnapshotUpdated,
}
