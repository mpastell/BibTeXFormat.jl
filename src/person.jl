"""A person or some other person-like entity.

>>> knuth = Person('Donald E. Knuth')
>>> knuth.first_names
[u'Donald']
>>> knuth.middle_names
[u'E.']
>>> knuth.last_names
[u'Knuth']

"""
struct Person

    first_names::Vector{String}
    middle_names::Vector{String}
    prelast_names::Vector{String}
    last_names::Vector{String}
    lineage_names::Vector{String}

end

import Base.==
valid_roles = Set(["author", "editor"])

const  style1_re = r"^(.+),\s*(.+)$"
const  style2_re = r"^(.+),\s*(.+),\s*(.+)$"

"""
:param string: The full name string.
    It will be parsed and split into separate first, last, middle,
    pre-last and lineage name parst.

    Supported name formats are:

    - von Last, First
    - von Last, Jr, First
    - First von Last

    (see BibTeX manual for explanation)

"""
function Person(s::String="", first::String="", middle::String="", prelast::String="", last::String="", lineage::String="")

    local person = Person(String[], String[],String[], String[], String[])

    string = strip(s)
    if length(s) >0
        _parse_string(person,s)
    end
    append!(person.first_names,split_tex_string(first))
    append!(person.middle_names,split_tex_string(middle))
    append!(person.prelast_names,split_tex_string(prelast))
    append!(person.last_names,split_tex_string(last))
    append!(person.lineage_names,split_tex_string(lineage))
    return person
end

"""A list of first and middle names together.
(BibTeX treats all middle names as first.)

>>> knuth = Person('Donald E. Knuth')
>>> knuth.bibtex_first_names
[u'Donald', u'E.']
"""
function bibtex_first_names(self::Person)
    return vcat(self.first_names, self.middle_names)
end

"""Extract various parts of the name from a string.

>>> p = Person('Avinash K. Dixit')
>>> print(p.first_names)
[u'Avinash']
>>> print(p.middle_names)
[u'K.']
>>> print(p.prelast_names)
[]
>>> print(p.last_names)
[u'Dixit']
>>> print(p.lineage_names)
[]
>>> print(six.text_type(p))
Dixit, Avinash K.
>>> p == Person(six.text_type(p))
True
>>> p = Person('Dixit, Jr, Avinash K. ')
>>> print(p.first_names)
[u'Avinash']
>>> print(p.middle_names)
[u'K.']
>>> print(p.prelast_names)
[]
>>> print(p.last_names)
[u'Dixit']
>>> print(p.lineage_names)
[u'Jr']
>>> print(six.text_type(p))
Dixit, Jr, Avinash K.
>>> p == Person(six.text_type(p))
True

>>> p = Person('abc')
>>> print(p.first_names, p.middle_names, p.prelast_names, p.last_names, p.lineage_names)
[] [] [] [u'abc'] []
>>> p = Person('Viktorov, Michail~Markovitch')
>>> print(p.first_names, p.middle_names, p.prelast_names, p.last_names, p.lineage_names)
[u'Michail'] [u'Markovitch'] [] [u'Viktorov'] []
"""
function _parse_string(self::Person, name::String)
    function  process_first_middle(parts)
        try
            push!(self.first_names,parts[1])
            append!(self.middle_names,parts[2:end])
        catch e
        end
    end

    function process_von_last(parts)
        # von cannot be the last name in the list
        von_last = parts[1:end-1]
        definitely_not_von = parts[end]
        if length(von_last)>0
            von, last = rsplit_at(von_last, is_von_name)
            append!(self.prelast_names,von)
            append!(self.last_names,last)
        end
        push!(self.last_names,definitely_not_von)
    end

    function find_pos(lst, pred)
        local i = 1
        for ( i, item) in enumerate(lst)
            if pred(item)
                return i
            end
        end
        return length(lst) + 1
    end

    function split_at(lst, pred)
        """Split the given list into two parts.

        The second part starts with the first item for which the given
        predicate is True.
        """
        pos = find_pos(lst, pred)
        return lst[1:pos-1], lst[pos:end]
    end

    function rsplit_at(lst, pred)
        rpos = find_pos(reverse(lst), pred)
        pos = length(lst) - rpos
        if pos < 0
            return lst, []
        else

        end
        return lst[1:pos], lst[pos+1:end]
    end

    function is_von_name(string)
        if isupper(string[1])
            return false
        end
        if isupper(string[1])
            return true
        else
            for (char, brace_level) in scan_bibtex_string(string)
                if brace_level == 0 && isalpha(char)
                    return islower(char)
                elseif brace_level == 1 && startswith(char,"\\")
                    return special_char_islower(char)
                end
            end
        end
        return false
    end

    function special_char_islower(special_char)
        control_sequence = true
        for char in special_char[2:end]  # skip the backslash
            if control_sequence
                if ! isalpha(char)
                    control_sequence = false
                end
            else
                if isalpha(char)
                    return islowercase(char)
                end
            end
        end
        return false
    end

    local parts = split_tex_string(name, ",")
    if length(parts) > 3
        report_error(InvalidNameString(name))
        last_parts = parts[2:end]
        parts = vcat(parts[1:2],join(last_parts, " "))
    end
    if length(parts) == 3  # von Last, Jr, First
        process_von_last(split_tex_string(parts[1]))
        append!(self.lineage_names,split_tex_string(parts[2]))
        process_first_middle(split_tex_string(parts[3]))
    elseif length(parts) == 2  # von Last, First
        process_von_last(split_tex_string(parts[1]))
        process_first_middle(split_tex_string(parts[2]))
    elseif length(parts) == 1  # First von Last
        parts = split_tex_string(name)
        first_middle, von_last = split_at(parts, is_von_name)
        if (!(length(von_last)>0)) && length(first_middle)>0
            last = pop!(first_middle)
            push!(von_last,last)
        end
        process_first_middle(first_middle)
        process_von_last(von_last)
    else
        # should hot really happen
        throw(name)
    end
end
function ==(self::Person, other::Person)
    return (
        self.first_names == other.first_names
        && self.middle_names == other.middle_names
        && self.prelast_names == other.prelast_names
        && self.last_names == other.last_names
        && self.lineage_names == other.lineage_names
    )
end
#=def __str__(self):
    # von Last, Jr, First
    von_last = ' '.join(self.prelast_names + self.last_names)
    jr = ' '.join(self.lineage_names)
    first = ' '.join(self.first_names + self.middle_names)
    return ', '.join(part for part in (von_last, jr, first) if part)

def __repr__(self):
    return 'Person({0})'.format(repr(six.text_type(self)))
=#
function get_part_as_text(self, ttype)
    names = getattr(self, ttype + "_names")
    return join(names, " ")
end

"""Get a list of name parts by `type`.

>>> knuth = Person('Donald E. Knuth')
>>> knuth.get_part('first')
[u'Donald']
>>> knuth.get_part('last')
[u'Knuth']
"""
function get_part(self::Person, ttype, abbr=false)

    names = getattr(self,ttype + "_names")
    if abbr
        names = [abbreviate(name) for name in names]
    end
    return names
end

function rich_first_names(self):
    """
    A list of first names converted to :ref:`rich text <rich-text>`.

    """

    return [Text.from_latex(name) for name in self.first_names]
end
function rich_middle_names(self):
    """
    A list of middle names converted to :ref:`rich text <rich-text>`.

    .. versionadded:: 0.20
    """
    return [Text.from_latex(name) for name in self.middle_names]
end
function rich_prelast_names(self):
    """
    A list of pre-last (aka von) name parts converted to :ref:`rich text <rich-text>`.

    .. versionadded:: 0.20
    """
    return [Text.from_latex(name) for name in self.prelast_names]
end
function rich_last_names(self):
    """
    A list of last names converted to :ref:`rich text <rich-text>`.

    .. versionadded:: 0.20
    """
    return [Text.from_latex(name) for name in self.last_names]
end
function rich_lineage_names(self::Person)
    """
    A list of lineage (aka Jr) name parts converted to :ref:`rich text <rich-text>`.
    """
    return [Text.from_latex(name) for name in self.lineage_names]
end
