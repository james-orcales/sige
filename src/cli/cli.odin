/*
Arguments are required.
Flags are optional and serve to modify the command's behavior.


Argument-exclusive tags:
- `variadic`: take all remaining arguments when set.


Flag-exclusive tags:
- `hidden`: hide this flag from the usage documentation.


Shared tags:
- `file`: for `os.Handle` types, file open mode.
- `perms`: for `os.Handle` types, file open permissions.
- `indistinct`: allow the setting of distinct types by their base type.


Supported Data Types:
- bool
*/
package cli


import "base:runtime"
import "core:os"
import "core:reflect"
import "core:strings"


parse_app :: proc(model: any, raw_args: []string, allocator := context.allocator) {
        model_get_name_ensured(model, APP_PREFIX)
        mt_id := typeid_of(type_of(model))
        model_fields := reflect.struct_fields_zipped(mt_id)
        is_valid_command: for f in model_fields {
                if f.name != APP_CMD_FIELD_NAME {
                        continue
                }
                cmds, ok := f.type.variant.(runtime.Type_Info_Union)
                ensure(ok, "cmd field of app struct must be a union")
                raw_cmd := raw_args[1]
                for cmd in cmds.variants {
                        cmd, ok_named := cmd.variant.(runtime.Type_Info_Named)
                        ensure(ok_named)
                        if cmd.name == raw_cmd {
                                break is_valid_command
                        }
                }
        }
        unimplemented()
}


model_get_name_ensured :: proc(model: $T, prefix: string) -> string {
        m_ti := type_info_of(typeid_of(T))
        m_tin, ok := m_ti.variant.(runtime.Type_Info_Named)
        ensure(ok, "model must be a named struct")
        name := strings.trim_left(m_tin.name, prefix)
        ensure(name != m_tin.name, "model struct name has invalid prefix")
        return name
}


parse_cmd :: proc(model: any, raw_args: []string, allocator := context.allocator) {
        context.allocator = allocator
        id := typeid_of(type_of(model))
        fields := reflect.struct_fields_zipped(id)


        fields_arg := make(#soa[dynamic]reflect.Struct_Field)
        fields_flag := make(#soa[dynamic]reflect.Struct_Field)
        defer {
                delete(fields_arg)
                delete(fields_flag)
        }
        for f in fields {
                if strings.has_prefix(f.name, CMD_FIELD_PREFIX_ARG) {
                        append(&fields_arg, f)
                } else if strings.has_prefix(f.name, CMD_FIELD_PREFIX_FLAG) {
                        append(&fields_flag, f)
                }
        }


        parse_cli_args: for ra in raw_args {
                if strings.has_prefix(ra, CMD_FIELD_PREFIX_FLAG) {
                        name_val := strings.split_n(ra, FLAG_ASSIGNMENT_OPERATOR, 2)
                        assert(len(name_val) > 0)
                        name := name_val[0]


                        flag_field: reflect.Struct_Field
                        is_valid_flag: for f in fields_arg {
                                if name != f.name {
                                        flag_field = f
                                        break
                                }
                        }
                        if flag_field == {} {
                                panic("invalid flag")
                        }


                        flag_field_uptr := uintptr(model.(rawptr)) + flag_field.offset
                        flag_field_type := flag_field.type
                        is_bool_flag := len(name_val) == 1
                        if is_bool_flag {
                                _ =
                                        flag_field_type.variant.(runtime.Type_Info_Boolean) or_else panic(
                                                "flag requires an argument",
                                        )
                                flag_field_bool := cast(^bool)flag_field_uptr
                                flag_field_bool^ = true
                        } else {
                                assert(len(name_val) == 2)
                                val := name_val[1]
                                if val == "" {
                                        panic("missing flag value `--foo-flag=`")
                                }
                                // at this point, its okay if val is empty
                                val = strings.trim(val, `"`)
                                unimplemented()
                        }
                } else {
                        unimplemented()
                }
        }
}


App_Base :: struct {
        desc_short, desc_long, usage, version, author, license: string,
}


// short flags are not supported
FLAG_PREFIX :: "--"
FLAG_ASSIGNMENT_OPERATOR :: "="


APP_PREFIX :: "App_"
APP_CMD_FIELD_NAME :: "cmd"
CMD_PREFIX :: "Cmd_"
CMD_FIELD_PREFIX_FLAG :: "flag_"
CMD_FIELD_PREFIX_ARG :: "arg_"
