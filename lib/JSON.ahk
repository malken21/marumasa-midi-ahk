/************************************************************************
 * @description JSON library for AHK v2 (Pure AHK implementation)
 ***********************************************************************/

class JSON {
    static True := {__json_type: "boolean", value: true}
    static False := {__json_type: "boolean", value: false}
    static Null := {__json_type: "null"}

    static Parse(json) {
        p := 1
        return this._ParseValue(json, &p)
    }

    static Stringify(obj) {
        if (IsObject(obj) && obj.HasProp("__json_type")) {
            if (obj.__json_type == "boolean")
                return obj.value ? "true" : "false"
            if (obj.__json_type == "null")
                return "null"
        }

        if obj is Array {
            res := "["
            for i, v in obj {
                res .= (i = 1 ? "" : ",") . this.Stringify(v)
            }
            return res . "]"
        } else if IsObject(obj) {
            res := "{"
            first := true
            if obj is Map {
                for k, v in obj {
                    res .= (first ? "" : ",") . '"' . k . '":' . this.Stringify(v)
                    first := false
                }
            } else {
                for k, v in obj.OwnProps() {
                    res .= (first ? "" : ",") . '"' . k . '":' . this.Stringify(v)
                    first := false
                }
            }
            return res . "}"
        } else if (obj is Integer || obj is Float) {
            return obj
        } else if (obj == "") {
            return '""'
        } else {
            return '"' . StrReplace(StrReplace(StrReplace(obj, "\", "\\"), '"', '\"'), "`n", "\n") . '"'
        }
    }

    static _ParseValue(json, &p) {
        p := RegExMatch(json, "\S", &m, p) ? m.Pos : p
        char := SubStr(json, p, 1)
        if (char == "{")
            return this._ParseObject(json, &p)
        if (char == "[")
            return this._ParseArray(json, &p)
        if (char == '"')
            return this._ParseString(json, &p)
        if RegExMatch(json, "i)\Gtrue", , p)
            return (p += 4, true)
        if RegExMatch(json, "i)\Gfalse", , p)
            return (p += 5, false)
        if RegExMatch(json, "i)\Gnull", , p)
            return (p += 4, "")
        if RegExMatch(json, "\G-?\d+(\.\d+)?([eE][+-]?\d+)?", &m, p)
            return (p += m.Len, m[0] + 0)
        throw Error("Unexpected character at position " . p . ": " . char)
    }

    static _ParseObject(json, &p) {
        obj := {}
        p++ ; skip {
        loop {
            p := RegExMatch(json, "\S", &m, p) ? m.Pos : p
            if (SubStr(json, p, 1) == "}")
                return (p++, obj)
            key := this._ParseString(json, &p)
            p := RegExMatch(json, "\G\s*:\s*", &m, p) ? p + m.Len : p
            val := this._ParseValue(json, &p)
            obj.%key% := val
            p := RegExMatch(json, "\G\s*([,}])", &m, p) ? p : p
            if (m[1] == "}")
                return (p++, obj)
            p++ ; skip ,
        }
    }

    static _ParseArray(json, &p) {
        arr := []
        p++ ; skip [
        loop {
            p := RegExMatch(json, "\S", &m, p) ? m.Pos : p
            if (SubStr(json, p, 1) == "]")
                return (p++, arr)
            arr.Push(this._ParseValue(json, &p))
            p := RegExMatch(json, "\G\s*([,\]])", &m, p) ? p : p
            if (m[1] == "]")
                return (p++, arr)
            p++ ; skip ,
        }
    }

    static _ParseString(json, &p) {
        if !RegExMatch(json, '\G"((?:[^"\\]|\\.)*)"', &m, p)
            throw Error("Invalid string at position " . p)
        p += m.Len
        str := m[1]
        
        str := StrReplace(str, '\"', '"')
        str := StrReplace(str, '\/', '/')
        str := StrReplace(str, '\b', '`b')
        str := StrReplace(str, '\f', '`f')
        str := StrReplace(str, '\n', '`n')
        str := StrReplace(str, '\r', '`r')
        str := StrReplace(str, '\t', '`t')
        str := StrReplace(str, '\\', '\')
        return str
    }
}
