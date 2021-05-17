Red [
    Title:   "Recalculator"
    Purpose: "A scientific calculator implemented in Red"
    Author: "Zwortex"
    File:    %recalculator.red
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes: { 
        This is a demo application writen for testing Red Language capabilities. 
        As such, many comments in the code may appear only relevant for and from newbies into this language.
        As such also, the implementation may not represent at all what might be considered as a good
        implementation using Red language. It might even appear somehow complex, more than it should
        be anyway. Keep in mind however that the intention of the author was not to take the straightest route, 
        rather to explore whatever capabilities the language offers.
    }
    Version: 0.1.0
    Date: 06/05/2021
    Changelog: {
        0.1.0 - 06/05/2021
            * initial version
    }
    Tabs:    4
    Usage: {
        
        The following assumes you have already installed the script in a directory along with the executable red.

        If not, please go to https://www.red-lang.org/p/download.html and retrieve the 
        last built version of red for your current environment, and install it along with this script.

        For running the script: 
            red recalculator.red

        For compiling the script:
            red -r -e -t Windows recalculator.red (for the standalone version)
            red -c -e -t Windows recalculator.red (for the version running against libRedRt.dll)
        That should produce the executable recalculator.exe in the same directory.

        For other target than Windows (not tested), please adapt the option -t as you wish. 

        For further details on Red and how to run it, please refer to https://github.com/red/red

        You may also load the script into a gui console that is already running. In such case, the 
        recalculator will opens up automatically.
        
        Once it is closed, you may start it again by typing the following command: 
            recalculator/run

        Once the recalculator has been started, its usage is pretty straightforward. 
        
        You may explore the following : standard operations ; extended fonctions in the option menus ;
        computations may be stacked/unstacked, modified or combined using variables (#1, #2...) ;
        undo/redo ; clear either a character, a line or the entire stack ; various parenthesis.

    }
    Needs:   'view
]

; All code is isolated from the global context by putting it in a dedicated context
recalculator: context [

; Global context
global: context? 'system

; Debug for the whole recalculator
; there is a debug field for each component though to turn on/off various parts of the code
debug: false


;; Reset some debug flags
;system/reactivity/debug?: off
;system/view/debug?: off

; cleanup reactions if need be
;clear-reactions

; unforce pretty display of float - not used anyway
;system/options/float/pretty?: true

; Assert function used accross the code
assert: function [
    "Throws an error if a test failed"
    :check [any-type!] "test to perform" ; a get-arg to transfer the condition as is to be evaled by do
    message [any-type!] "error message if test failed"
][
    if not do :check [
        mess: either block? message [ rejoin mess ][ to-string message ]
        do make error! mess
    ]
]

;
; Function pack
; mostly wrappers around standard functions and few additional ones
;
; comment [ ; a hack to turn on/off certain parts of the code, in case of running blocks or strings
;comment [
funcs: context [

    debug: false

    ; Some constant values retrieved from core scripts
    ; some are used, some not
    max-float: +1.7E+308
    min-float: -1.7E+308
    max-integer: 2147483647
    min-integer: -2147483648
    positive-inf: 1.#INF ; not used - just to remember
    negative-inf: -1.#INF
    not-a-number: 1.#NaN ; err value when dividing by 0
    float-epsilon: 2.2204460492503131E-16 ; below that displayed as 0.0

    ;
    ; Special form
    ; @ZWT should be reviewed thoroughly
    ;
    form: function [
        "Form string a value (float or integer) in an attempt to mix the standard form and standard probe."
        value [float! integer! none!] ; none! if no value computed
        return: [string!]
    ][
        res: none
        res: case [
            integer! == type? value [ global/form value ] ; delegate to standard form
            none? value [ "Invalid" ] ; clarify none? vs NaN - @ZWT TODO
            NaN? value [ "Invalid" ] ; beware that value = 1.#NaN never matches even with 1.#NaN - therefore NaN?
            value = 1.#INF [ "Positive Overflow" ]
            value = -1.#INF [ "Negative Overflow" ]
            value = 0 [ "0" ] ; no 0.0
            ( (global/absolute value) < float-epsilon ) [ global/mold value ] ; otherwise 0.0 if tiny number
            true [ 
                res: global/form value
                ; cleanup trailing ".0" if any
                if all [ 
                    not find res #"e"
                    ( back back tail res ) = ".0"
                ][
                    take/part/last res 2
                ]
                res
            ]
        ]
        ; add a separator for thousands
        either none? res [
            res: copy ""
            if debug [
                print [ "Unexpected form string none for value" mold value ]
            ]
        ][
            s: res
            while [ all [ not tail? s #"0" <= s/1 s/1 <= #"9" ] ][ s: next s ] ; forward across leading digits
            i: 0
            until [ ; backwards inserting a separator every three digits
                s: back s
                i: ( mod i 3 ) + 1
                if i = 3 [
                    insert s #" "
                ]
                s == res
            ]
            if res/1 == #" " [
                take res
            ]
            if debug [
                print [ "Value:" mold value "output:" res ]
            ]
        ]
        return res
    ]

    ;
    ; unary operations
    ;
    exps: function [
        value1 [number!]
        value2 [integer!]
        return: [number!]
    ][
        return value1 * ( 10 ** value2 )
    ]

    inverse: function [
        value [number!]
        return: [float!]
    ][
        return 1 / value
    ]

    negate: function [
        value [number!]
        return: [float!]
    ][
        return global/negate value
    ]

    absolute: function [
        value [number!]
        return: [float!]
    ][
        return global/absolute value
    ]

    factorial: function [
        value [integer!]
        return: [number!]
    ][
        if value < 0 [ return 1.#NaN ] ; Expecting positive integer
        if value = 0 [ return 0 ]
        res: either value > 12 [1.0][1] ; 13! = 6 227 020 800 that extends max int = 2 147 483 647
        until [
            res: res * value
            value: value - 1
            zero? value
        ]
        return res
    ]

    ; @ZWT TODO : make it static so that the returned value is kept for the current expression
    ; probably to be implemented at the expression level
    random: function [
        value [number!]
        return: [number!]
    ][
        return global/random value
    ]

    ;
    ; Binary operations
    ;

    add: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        r: none
        if all [ type? v1 == integer! type? v2 == integer! ][
            r: attempt [ v1 + v2 ]
        ]
        if none? r [
            r: attempt [ 0.0 + v1 + v2 ]
        ]
        return r ; possibly 1.#INF or -1.#INF
    ]

    subtract: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        return add v1 ( 0 - v2 )
    ]

    multiply: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        r: none
        if all [ type? v1 == integer! type? v2 == integer! ] [
            r: attempt [ v1 * v2 ]
        ]
        if none? r [
            r: attempt [ 1.0 * v1 * v2 ]
        ]
        return r ; possibly 1.#INF or -1.#INF
    ]

    implicit-multiply: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        return multiply v1 v2
    ]

    divide: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        r: attempt [ v1 / v2 ]
        if none? r [
            r: ( sign? v1 ) * 1.#NaN
        ]
        return r
    ]

    modulo: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        r: attempt [ global/mod v1 v2 ]
        if none? r [
            r: ( sign? v1 ) * 1.#NaN
        ]
        return r
    ]

    remainder: function [
        v1 [number!]
        v2 [number!]
        return: [number!]
    ][
        r: attempt [ global/remainder v1 v2 ]
        if none? r [
            r: ( sign? v1 ) * 1.#NaN
        ]
        return r
    ]

    ;
    ; Power functions
    ;

    power-2: function [
        value [number!]
        return: [number!]
    ][
        return global/power value 2
    ]

    square-2: function [
        value [number!]
        return: [number!]
    ][
        return global/sqrt value
    ]

    power-3: function [
        value [number!]
        return: [number!]
    ][
        return global/power value 3
    ]

    square-3: function [
        value [number!]
        return: [number!]
    ][
        return global/power value ( 1 / 3 )
    ]

    power: function [
        value [number!]
        exp [integer!]
        return: [number!]
    ][
        return global/power value exp
    ]

    square: function [
        value [number!]
        exp [integer!]
        return: [number!]
    ][
        return global/power value ( 1 / exp )
    ]

    ;
    ; Trigonometric constant and functions
    ;

    PI: global/PI

    sine: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        return switch/default mode [
            deg [ global/sine value ]
            rad [ global/sine/radians value ]
            grad [ global/sine ( value * 360 / 400 ) ]
        ] [ none ]
    ]

    cosine: function [
        value [number!]
        mode [word!]
        return: [number!] 
    ][
        return switch mode [
            deg [ global/cosine value ]
            rad [ global/cosine/radians value ]
            grad [ global/cosine ( value * 360 / 400 ) ]
        ]
    ]

    tangent: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        return switch mode [
            deg [ global/tangent value ]
            rad [ global/tangent/radians value ]
            grad [ global/tangent ( value * 360 / 400 ) ]
        ]
    ]

    sine-1: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        if ( value < -1 ) or ( value > 1 ) [
            return 1.#NaN
        ]
        return switch mode [
            deg [ global/arcsine value ]
            rad [ global/arcsine/radians value ]
            grad [ ( global/arcsine value ) * 400 / 360 ]
        ]
    ]

    cosine-1: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        if ( value < -1 ) or ( value > 1 ) [
            return 1.#NaN
        ]
        return switch mode [
            deg [ global/arccosine value ]
            rad [ global/arccosine/radians value ]
            grad [ ( global/arccosine value ) * 400 / 360 ]
        ]
    ]

    tangent-1: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        return switch mode [
            deg [ global/arctangent value ]
            rad [ global/arctangent/radians value ]
            grad [ ( global/arctangent value ) * 400 / 360 ]
        ]
    ]

    cosecant: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        res: sine value mode
        if ( res == 0 ) [
            return 1.#NaN
        ]
        return 1 / res
    ]

    secant: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        res: cosine value mode
        if ( res == 0 ) [
            return 1.#NaN
        ]
        return 1 / res
    ]

    cotangent: function [
        value [number!]
        mode [word!]
        return: [number!]
    ][
        res: sine value mode
        if ( res == 0 ) [
            return 1.#NaN
        ]
        return ( cosine value mode ) / res
    ]

    cosecant-1: function [
        "Arccosecant y = arccsc(x) <=> csc(y) = x // arccsc(x) = arcsin(1/x) "
        value [number!]
        mode [word!]
        return: [number!]
    ][
        if ( value == 0 ) [
            return 1.#NaN
        ]
        return sine-1 ( 1 / value ) mode
    ]

    secant-1: function [
        "Arcsecant y = arcsec(x) <=> sec(y) = x // arsec(x) = arccos(1/x)"
        value [number!]
        mode [word!]
        return: [number!]
    ][
        if ( value == 0 ) [
            return 1.#NaN
        ]
        return cosine-1 ( 1 / value ) mode
    ]

    cotangent-1: function [
        "Arccotangent y = arccot(x) <=> cot(y) = x // arccot(x) = arctan(1/x)"
        value [number!]
        mode [word!]
        return: [number!]
    ][
        if ( value == 0 ) [
            return 1.#NaN
        ]
        return tangent-1 ( 1 / value ) mode
    ]

    ; All variants of trigonometric functions
    ; @ZWT : how about using macros ?

    ; radian variants
    sine-r: function [v] [sine v 'rad]
    cosine-r: function [v] [cosine v 'rad]
    tangent-r: function [v] [tangent v 'rad]
    sine-1-r: function [v] [sine-1 v 'rad]
    cosine-1-r: function [v] [cosine-1 v 'rad]
    tangent-1-r: function [v] [tangent-1 v 'rad]
    cosecant-r: function [v] [cosecant v 'rad]
    secant-r: function [v] [secant v 'rad]
    cotangent-r: function [v] [cotangent v 'rad]
    cosecant-1-r: function [v] [cosecant-1 v 'rad]
    secant-1-r: function [v] [secant-1 v 'rad]
    cotangent-1-r: function [v] [cotangent-1 v 'rad]

    ; deg variants
    sine-d: function [v] [sine v 'deg]
    cosine-d: function [v] [cosine v 'deg]
    tangent-d: function [v] [tangent v 'deg]
    sine-1-d: function [v] [sine-1 v 'deg]
    cosine-1-d: function [v] [cosine-1 v 'deg]
    tangent-1-d: function [v] [tangent-1 v 'deg]
    cosecant-d: function [v] [cosecant v 'deg]
    secant-d: function [v] [secant v 'deg]
    cotangent-d: function [v] [cotangent v 'deg]
    cosecant-1-d: function [v] [cosecant-1 v 'deg]
    secant-1-d: function [v] [secant-1 v 'deg]
    cotangent-1-d: function [v] [cotangent-1 v 'deg]

     ; gradient variants
    sine-g: function [v] [sine v 'grad]
    cosine-g: function [v] [cosine v 'grad]
    tangent-g: function [v] [tangent v 'grad]
    sine-1-g: function [v] [sine-1 v 'grad]
    cosine-1-g: function [v] [cosine-1 v 'grad]
    tangent-1-g: function [v] [tangent-1 v 'grad]
    cosecant-g: function [v] [cosecant v 'grad]
    secant-g: function [v] [secant v 'grad]
    cotangent-g: function [v] [cotangent v 'grad]
    cosecant-1-g: function [v] [cosecant-1 v 'grad]
    secant-1-g: function [v] [secant-1 v 'grad]
    cotangent-1-g: function [v] [cotangent-1 v 'grad]

    ;
    ; Logarithm functions
    ;

    E: global/exp 1

    log-e: function [
        value [number!]
        return: [number!]
    ][
        return global/log-e value
    ]

    log-2: function [
        value [number!]
        return: [number!]
    ][
        return global/log-2 value
    ]

    log-10: function [
        value [number!]
        return: [number!]
    ][
        return global/log-10 value
    ]

    exp-e: function [
        value [number!]
        return: [number!]
    ][
        return global/exp value
    ]

    exp-2: function [
        value [number!]
        return: [number!]
    ][
        return global/power 2 value
    ]

    exp-10: function [
        value [number!]
        return: [number!]
    ][
        return global/power 10 value
    ]

    ;
    ; round functions
    ;

    round: function [
        value [number!]
        return: [integer!]
    ][
        return global/round value
    ]

    ceil: function [
        value [number!]
        return: [integer!]
    ][
        return global/round/ceiling value
    ]

    floor: function [
        value [number!]
        return: [integer!]
    ][
        return global/round/floor value
    ]

    ;
    ; Hyperbolic functions
    ;

    sinh: function [
        "Sinus hyperbolique"
        x [number!]
        return: [number!]
    ][
        return ( ( global/exp x ) - ( global/exp ( 0 - x ) ) ) / 2
    ]

    cosh: function [
        "Cosinus hyperbolique"
        x [number!]
        return: [number!]
    ][
        return ( ( global/exp x ) + ( global/exp ( 0 - x ) ) ) / 2
    ]

    tanh: function [
        "Tangente hyperbolique"
        x [number!]
        return: [number!]
    ][
        return ( sinh x ) / ( cosh x )
    ]

    csch: function [
        "Cosecante hyperbolique"
        x [number!]
        return: [number!]
    ][
        return 1 / ( sinh x )
    ]

    sech: function [
        "Secante hyperbolique"
        x [number!]
        return: [number!]
    ][
        return 1 / ( cosh x )
    ]

    coth: function [
        "Cotangente hyperbolique"
        x [number!]
        return: [number!]
    ][
        return ( cosh x ) / ( sinh x )
    ]

    sinh-1: function [
        "Inverse hyperbolic sine - arcsinh"
        x [number!]
        return: [number!]
    ][
        return global/log-e (
            x + global/sqrt ( ( x ** 2 ) + 1 )
        )
    ]

    cosh-1: function [
        "Inverse hyperbolic cosine - arccosh"
        x [number!]
        return: [number!]
    ][
        return global/log-e (
            x + global/sqrt ( ( x ** 2 ) - 1 )
        )
    ]

    tanh-1: function [
        "Inverse hyperbolic tangent - arctanh"
        x [number!]
        return: [number!]
    ][
        return ( 1 / 2 ) * global/log-e (
            ( 1 + x ) / ( 1 - x )
        )
    ]

    csch-1: function [
        "Inverse hyperbolic cosecante -  arccsch"
        x [number!]
        return: [number!]
    ][
        return global/log-e (
            ( 1 / x )
            +
            global/sqrt (
                ( 1 / ( x ** 2 ) )
                +
                1
            )
        )
    ]

    sech-1: function [
        "Inverse hyperbolic secant - arcsech"
        x [number!]
        return: [number!]
    ][
        return global/log-e (
            ( 1 + global/sqrt ( 1 - ( x ** 2 ) ) )
            /
            x
        )
    ]

    coth-1: function [
        "Inverse hyperbolic cotangent - arccoth"
        x [number!]
        return: [number!]
    ][
        return ( 1 / 2 ) * global/log-e (
            ( x + 1 ) / ( x - 1 )
        )
    ]

    ;
    ; conversion
    ;
    to-dms: function [
        "Return degree value in degree minute second format"
        value [number!]
        return: [number!]
    ][
        vd: global/round/down value
        value-m: ( value - vd ) * 60
        vm: global/round/down value-m
        value-s: ( value-m - vm ) * 60 
        return vd + ( vm / 100 ) + ( value-s / 10000 )
    ]

    to-deg: function [
        "Convert degree value from dms to decimal degree"
        value [number!]
        return: [number!]
    ][
        vd: global/round/down value
        vm: global/round/down ( ( value - vd ) * 100 )
        vs: ( value - vd - ( vm / 100 ) ) * 10000
        return vd + ( vm / 60 ) + ( vs / 3600 )
    ]

    pourcent: function [
        value [number!]
        return: [number!]
    ][
        return ( value / 100 )
    ]

    ;
    ; Dates
    ;
    date-subtract: function [
        dt1 [date!]
        dt2 [date!]
    ][
        if dt1 > dt2 [
            m: dt2 
            dt2: dt1
            dt1: m 
        ]
        ddd: dt2 - dt1
        dy: dt2/year - dt1/year
        dt1/year: dt1/year + dy
        either dt1 > dt2 [ 
            dy: dy - 1
            dm: (12 - dt1/month) + dt2/month
        ][
            dm: dt2/month - dt1/month
        ]
        dt1/month: dt2/month
        if dt1 > dt2 [
            dm: dm - 1
            dt1/month: dt1/month - 1
        ]
        dd: dt2 - dt1
        probe dd
        dw: global/round/floor ( dd / 7 )
        dd: dd - ( 7 * dw )
        probe reduce [ ddd dy dm dw dd ]
    ]
]
;funcs
;]

;----------------------------------------------------------------------------
; Keys map
; a table of reference of all available keys : be it digits, operators, functions
; control comands
;----------------------------------------------------------------------------

;-------------------------------------------------------------------
; map of all keys 
; block structure 
; /1 : 'symbol/function
; /2 : key type
; /3 : button text
; /4 : key text
; /5 : pretty text left
; /6 : pretty text right
;--------------------------------------------------------------------

;;
;; Below some characters are a bit advanced for standard fonts
;; in particular the one used by ceil, floor and the h in the hyperbolic functions
;; other characters do not provoke particular issues
;;

;comment [
keys: #(

    ;;
    ;; literals
    ;;
    var: [var literal "#" "#" "#"]
    paren-l: [paren-l literal "(" "(" ""]
    paren-r: [paren-r literal ")" ")" ""]
    subexp: [subexp literal "" "" "(" ")"]
    
    ; possible spacers
    ets-spacer: [ets-spacer literal "(←⦆" "(←⦆" "(←⦆"]
    efs-spacer: [efs-spacer literal "(→⦆" "(→⦆" "(→⦆"]
    ste-spacer: [ste-spacer literal "⦅→)" "⦅→)" "⦅→)"]
    sfe-spacer: [sfe-spacer literal "⦅←)" "⦅←)" "⦅←)"]

    ; decimal separator
    decimal-separator: [decimal-separator literal "," "," ""]

    ; digits
    n0: [n0 literal "0" "0" ""]
    n1: [n1 literal "1" "1" ""]
    n2: [n2 literal "2" "2" ""]
    n3: [n3 literal "3" "3" ""]
    n4: [n4 literal "4" "4" ""]
    n5: [n5 literal "5" "5" ""]
    n6: [n6 literal "6" "6" ""]
    n7: [n7 literal "7" "7" ""]
    n8: [n8 literal "8" "8" ""]
    n9: [n9 literal "9" "9" ""]

    ; constants
    E: [E constant "𝑒" "𝑒" "𝑒"]
    PI: [PI constant "π" "π" "π"]

    ;;
    ;; Binary operators and functions
    ;;

    ; additions
    add: [add binary "+" "+" "+"]
    subtract: [subtract binary "−" "−" "−"] ; minus − / @ZWT should allow both
    
    ; multiplicatives
    multiply: [multiply binary "×" "×" "×"]
    divide: [divide binary "÷" "÷" "÷"]
    modulo: [modulo binary "mod" "mod" "mod"]
    remainder: [remainder binary "rem" "rem" "rem"]

    ; implicit multiplications (i.e. two terms following without an operator in between)
    implicit-multiply: [implicit-multiply binary "⋅" "⋅" "⋅"]

    ; powers
    exps: [exps binary "E" "[E]" "E"]
    power: [power binary "𝑥ʸ" "↑" "↑"]
    square: [square binary "ʸ√𝑥" "↑/" "↑/"]

    ;;
    ;; Unary operators and functions
    ;;

    ; unary rounding operations
    ; also works as separator
    absolute: [absolute unary "|𝑥|" "|x|" "|" "|"]
    absolute?: [absolute? literal "?" "[absolute?]" "?" ""] ; ambiguous absolute delimiter resolved in spacer
    round: [round unary "[𝑥]" "[x]" "[" "]"]
    ceil: [ceil unary "⎡x⎤" "⎡x⎤" "⎡" "⎤"] ; ⌈x⌉
    floor: [floor unary "⎣x⎦" "⎣x⎦" "⎣" "⎦"] ; ⌊x⌋

    ; unary operations
    factorial: [factorial unary "n!" "[n!]" "" "!"]
    negate: [negate unary "-𝑥" "[-]" "-" ""] ; hyphen -
    inverse: [inverse unary "¹∕𝑥" "⁽⁻¹⁾" "" "⁻¹"]
    pourcent: [pourcent unary "%" "[%]" "" "%"]

    ; @ZWT - special unary operation - random
    ; its value changes at each re-evaluation.
    ; as expression are rebuilt all the time currently, expressions
    ; that use random also change of values all the time.
    random: [random unary "rand" "[rand]" "rand" ""]

    ; unary power functions
    power-2: [power-2 unary "𝑥²" "⁽²⁾" "" "²"]
    square-2: [square-2 unary "√𝑥" "[√]" "√" ""]
    power-3: [power-3 unary "𝑥³" "⁽³⁾" "" "³"]
    square-3: [square-3 unary "³√𝑥" "[³√]" "³√" ""]

    ; trigonometric functions - radian
    sine-r: [sine-r unary "sinᵣ" "[sinᵣ]" "sinᵣ" ""]
    cosine-r: [cosine-r unary "cosᵣ" "[cosᵣ]" "cosᵣ" ""]
    tangent-r: [tangent-r unary "tanᵣ" "[tanᵣ]" "tanᵣ" ""]
    sine-1-r: [sine-1-r unary "sinᵣ⁻¹" "[sinᵣ⁻¹]" "sinᵣ⁻¹" ""]
    cosine-1-r: [cosine-1-r unary "cosᵣ⁻¹" "[cosᵣ⁻¹]" "cosᵣ⁻¹" ""]
    tangent-1-r: [tangent-1-r unary "tanᵣ⁻¹" "[tanᵣ⁻¹]" "tanᵣ⁻¹" ""]
    cosecant-r: [cosecant-r unary "cscᵣ" "[cscᵣ]" "cscᵣ" ""]
    secant-r: [secant-r unary "secᵣ" "[secᵣ]" "secᵣ" ""]
    cotangent-r: [cotangent-r unary "cotᵣ" "[cotᵣ]" "cotᵣ" ""]
    cosecant-1-r: [cosecant-1-r unary "cscᵣ⁻¹" "[cscᵣ⁻¹]" "cscᵣ⁻¹" ""]
    secant-1-r: [secant-1-r unary "secᵣ⁻¹" "[secᵣ⁻¹]" "secᵣ⁻¹" ""]
    cotangent-1-r: [cotangent-1-r unary "cotᵣ⁻¹" "[cotᵣ⁻¹]" "cotᵣ⁻¹" ""]

    ; trigonometric functions - degrees
    sine-d: [sine-d unary "sin₀" "[sin₀]" "sin₀" ""]
    cosine-d: [cosine-d unary "cos₀" "[cos₀]" "cos₀" ""]
    tangent-d: [tangent-d unary "tan₀" "[tan₀]" "tan₀" ""]
    sine-1-d: [sine-1-d unary "sin₀⁻¹" "[sin₀⁻¹]" "sin₀⁻¹" ""]
    cosine-1-d: [cosine-1-d unary "cos₀⁻¹" "[cos₀⁻¹]" "cos₀⁻¹" ""]
    tangent-1-d: [tangent-1-d unary "tan₀⁻¹" "[tan₀⁻¹]" "tan₀⁻¹" ""]
    cosecant-d: [cosecant-d unary "csc₀" "[csc₀]" "csc₀" ""]
    secant-d: [secant-d unary "sec₀" "[sec₀]" "sec₀" ""]
    cotangent-d: [cotangent-d unary "cot₀" "[cot₀]" "cot₀" ""]
    cosecant-1-d: [cosecant-1-d unary "csc₀⁻¹" "[csc₀⁻¹]" "csc₀⁻¹" ""]
    secant-1-d: [secant-1-d unary "sec₀⁻¹" "[sec₀⁻¹]" "sec₀⁻¹" ""]
    cotangent-1-d: [cotangent-1-d unary "cot₀⁻¹" "[cot₀⁻¹]" "cot₀⁻¹" ""]
    to-dms: [to-dms unary "→dms" "[→dms]" "→dms" ""]
    to-deg: [to-deg unary "→deg" "[→deg]" "→deg" ""]

    ; trigonometric functions - gradient
    sine-g: [sine-g unary "sin₉" "[sin₉]" "sin₉" ""]
    cosine-g: [cosine-g unary "cos₉" "[cos₉]" "cos₉" ""]
    tangent-g: [tangent-g unary "tan₉" "[tan₉]" "tan₉" ""]
    sine-1-g: [sine-1-g unary "sin₉⁻¹" "[sin₉⁻¹]" "sin₉⁻¹" ""]
    cosine-1-g: [cosine-1-g unary "cos₉⁻¹" "[cos₉⁻¹]" "cos₉⁻¹" ""]
    tangent-1-g: [tangent-1-g unary "tan₉⁻¹" "[tan₉⁻¹]" "tan₉⁻¹" ""]
    cosecant-g: [cosecant-g unary "csc₉" "[csc₉]" "csc₉" ""]
    secant-g: [secant-g unary "sec₉" "[sec₉]" "sec₉" ""]
    cotangent-g: [cotangent-g unary "cot₉" "[cot₉]" "cot₉" ""]
    cosecant-1-g: [cosecant-1-g unary "csc₉⁻¹" "[csc₉⁻¹]" "csc₉⁻¹" ""]
    secant-1-g: [secant-1-g unary "sec₉⁻¹" "[sec₉⁻¹]" "sec₉⁻¹" ""]
    cotangent-1-g: [cotangent-1-g unary "cot₉⁻¹" "[cot₉⁻¹]" "cot₉⁻¹" ""]

    ; hyperbolic functions
    ; initially sinₕ however the h is not well supported on all fonts,
    ; as a replacement 
    sinh: [sinh unary "sinₕ" "[sinₕ]" "sinₕ" ""]
    cosh: [cosh unary "cosₕ" "[cosₕ]" "cosₕ" ""]
    tanh: [tanh unary "tanₕ" "[tanₕ]" "tanₕ" ""]
    sinh-1: [sinh-1 unary "sinₕ⁻¹" "[sinₕ⁻¹]" "sinₕ⁻¹" ""]
    cosh-1: [cosh-1 unary "cosₕ⁻¹" "[cosₕ⁻¹]" "cosₕ⁻¹" ""]
    tanh-1: [tanh-1 unary "tanₕ⁻¹" "[tanₕ⁻¹]" "tanₕ⁻¹" ""]
    csch: [csch unary "cscₕ" "[cscₕ]" "cscₕ" ""]
    sech: [sech unary "secₕ" "[secₕ]" "secₕ" ""]
    coth: [coth unary "cotₕ" "[cotₕ]" "cotₕ" ""]
    csch-1: [csch-1 unary "cscₕ⁻¹" "[cscₕ⁻¹]" "cscₕ⁻¹" ""]
    sech-1: [sech-1 unary "secₕ⁻¹" "[secₕ⁻¹]" "secₕ⁻¹" ""]
    coth-1: [coth-1 unary "cotₕ⁻¹" "[cotₕ⁻¹]" "cotₕ⁻¹" ""]

    ; log / exp
    log-2: [log-2 unary "log₂" "[log₂]" "log₂" ""]
    log-e: [log-e unary "logₑ" "[logₑ]" "logₑ" ""]
    log-10: [log-10 unary "log₁₀" "[log₁₀]" "log₁₀" ""]
    exp-2: [exp-2 unary "2ˣ" "[2ˣ]" "2↑" ""] ; @ZWT ambiguous but here with no space
    exp-e: [exp-e unary "𝑒ˣ" "[𝑒ˣ]" "𝑒↑" ""] ; @ZWT ambiguous but here with no space
    exp-10: [exp-10 unary "10ˣ" "[10ˣ]" "10↑" ""] ; @ZWT ambiguous but here with no space

    ;;
    ;; Control keys - not for output
    ;;

    ; controls
    undo: [undo control "↶" "" ""]
    redo: [redo control "↷" "" ""]
    clear-expr: [clear-expr control "≪" "" ""]
    clear-all: [clear-all control "⋘" "" ""] 
    back-space: [back-space control "<" "" ""]
    enter: [enter control "⮠" "" ""]
    degree: [degree control "Deg…" "" "" ""]
    radian: [radian control "Rad…" "" "" ""]
    gradient: [gradient control "Grad…" "" "" ""]
)
; keys
;]

;----------------------------------------------------------------------------
; A tree structure for holding the syntaxic trees produced by the analyser
; The same strategy is used as with the expr object. A "big" object (tree) has 
; all the knowhow and manipulates little tiny nodes that hold the data.
; But instead of model and expr objects, nodes are merely blocks with named slots.
; Expressions are implemnented as separate trees. Each expression
; is a root node that breaks down into a binary tree of nodes for the operations,
; fonctions, subexpressions and values.
; Variables are special unary nodes that hold a reference to a separate tree.
; They are maintained by the model and expr objects that is responsibile
; for preventing the cycles (an expression that would refer itself directly
; or indirectly )
;----------------------------------------------------------------------------
;comment [
; this one requires encap -e
tree: context [

    ; having a field debug per context is a simple means of turning on/off debugging 
    ; in various parts of the code
    debug: false

    ; a type that might not be useful but just look nice to have
    type: 'tree

    ;
    ; Prototype objects at its core - no objects at all but blocks with named slots !
    ;
    node0: compose [
        node-type: node0
        label: (none)
        value: (none)
        extra: (none)
        parent: (none)
    ]
    node1: compose [
        (node0)
        child: (none)
    ] 
    node1/node-type: 'node1
    node2: compose [
        (node0)
        left: (none)
        right: (none)
    ]
    node2/node-type: 'node2

    ; The factory of nodes
    create: function [
        "Create a node"
        label [any-word!]
        /with value [any-type!]
        /extra extra-value [any-type!]
        /unary child [block!] "Child node"
        /binary
            left [block!] "Left node"
            right [block!] "Right node"
        return: [block!]
    ][
        n: none
        ; either leaf, unary or binary
        assert (
            any [
                all [ not unary not binary ]
                all [ unary not binary ]
                all [ binary not unary ]
            ]
        )
        case [
            not any [ unary binary ][
                n: copy node0
            ]
            unary [
                assert ( all [ child node? child none? child/parent ] ) "Child should exist and with no parent"
                n: copy node1
                n/child: child
                child/parent: n
            ]
            binary [
                assert ( all [ left node? left none? left/parent ] ) "Left should exist and with no parent"
                assert ( all [ right node? right none? right/parent ] ) "Right should exist and with no parent"
                n: copy node2
                n/left: left
                left/parent: n
                n/right: right
                right/parent: n
            ]
        ]
        n/label: to-word label
        n/value: if with [value]
        n/extra: if extra [extra-value]
        if debug [
            print ["Newly created node" as-string n]
        ]
        n
    ]

    ;;
    ;; Mutation, not used but interesting to be aware of
    ;; one of the benefice of using blocks in lieu of objects is 
    ;; the ability to mutate a block, which is not possible with a regular object !
    ;;
    mutate: function [
        "The target block is modified with the provided slot/value"
        node [block!] "Target block"
        /leaf
        /unary child [block!] "Child node"
        /binary
            left [block!] "Left node"
            right [block!] "Right node"
        return: [block!] ; mutated object
    ][
        check-node: function [ n [block!] parent [block!] ][
            all [
                n
                node? n
                n <> parent
                none? n/parent
            ]
        ]
        case [
            leaf [
                switch node/node-type [
                    node0 []
                    node1 [
                        node/child/parent: none
                        remove/part find node 'child 2
                    ]
                    node2 [
                        node/left/parent: none
                        node/right/parent: none
                        remove/part find node 'left 2
                        remove/part find node 'right 2
                    ]
                ]
                node/node-type: 'node0
            ]
            unary [
                switch node/node-type [
                    node0 [
                        append node compose [child: (none)]
                    ]
                    node1 [
                        node/child/parent: none
                    ]
                    node2 [
                        node/left/parent: none
                        node/right/parent: none
                        remove/part find node 'left 2
                        remove/part find node 'right 2
                        append node compose [child: (none)]
                    ]
                ]
                assert ( check-node child node ) "Child should be a free node different from parent node"
                node/node-type: 'node1
                node/child: child
                node/child/parent: node
            ]
            binary [
                 switch node/node-type [
                    node0 [
                        append node compose [left: (none)]
                        append node compose [right: (none)]
                    ]
                    node1 [
                        node/child/parent: none
                        remove/part find node 'child 2
                        append node compose [left: (none)]
                        append node compose [right: (none)]
                    ]
                    node2 [
                        node/left/parent: none
                        node/right/parent: none
                    ]
                ]
                assert ( check-node left node ) "Left should be a free node, different from parent node"
                assert ( check-node right node ) "Right should be a free node, different from parent node"
                node/node-type: 'node2
                node/left: left
                left/parent: node
                node/right: right
                right/parent: node
            ]
        ]
        node
    ]

    ;
    ; various chekers and accessors
    ;
    node?: function [
        "True if value is a node object"
        value [any-type!] 
        return: [logic!] 
    ][
        all [ 
            block? value
            find value 'node-type
        ]
    ]
    leaf?: function [ 
        "True if value is a leaf node"
        node [block!]
        return: [logic!] 
    ][
        'node0 == node/node-type
    ]
    unary?: function [
        "True if unary node"
        node [block!] "Node object"
        return: [logic!]
    ][
        return 'node1 == node/node-type
    ]
    binary?: function [
        "True if binary node"
        node [block!] "Node object"
        return: [logic!]
    ][
        return 'node2 == node/node-type
    ]
    nb-children: function [
        "return nb children"
        node [block!]
        return: [integer!]
    ][
        switch node/node-type [
            ; the tricky thing with switch is that the value checked is not interpreted
            ; here node0 means the word node0, not what is meant by this particular 
            ; word. Normally you would compare node/node-type against 'node0 that is
            ; interpreted as node0. But switch works differently.
            ; This is nowhere else to be seen in other parts of the language.
            ; That may be useful at low levels but that turns out to be
            ; mainly cumbersome at higher levels
            node0 [ return 0 ]
            node1 [ return 1 ]
            node2 [ return 2 ]
        ]
        ; here a do make error! with a string as spec. will trigger 
        ; a user defined error that may be trapped with try
        do make error! "nb-children - expecting node value"
    ]
    ; various navigation functions
    left: function [
        "Returns left node or none if leaf node"
        node [block!]
        return: [block! none!] 
    ][
        switch node/node-type [
            node0 [ return none ]
            node1 [ return node/child ]
            node2 [ return node/left ]
        ]
        do make error! "left - expecting node value"
    ]
    right: function [
        "Returns right child or none if leaf node"
        node [block!]
        return: [block! none!]
    ][
        switch node/node-type [
            node0 [ return none ]
            node1 [ return node/child ]
            node2 [ return node/right ]
        ]
        do make error! "right - expecting node value"
    ]
    leftmost-leaf: function [
        "Returns the leftmost leaf within this node tree"
        node [block!]
        return: [block!]
    ][
        assert (node? node) "leftmost-leaf - expecting node value"
        while [ not leaf? node ] [
            node: left node
        ]
        return node
    ]
    rightmost-leaf: function [
        "Returns the rightmost leaf within this node tree"
        node [block!]
        return: [block!]
    ][
        assert (node? node) "rightmost-leaf - expecting node value"
        while [ not leaf? node ] [
            node: right node
        ]
        return node
    ]
    ;; externalize search fonction - used in search-variables (compile error otherwise)
    check: function [n [block!] return: [logic!]][
            n/label == 'var
    ]
    ;; Search a tree for variables
    search-variables: function [
        node [block!]
        return: [block!] ; block possibly empty with the matched nodes
    ][
        return search node :check
    ]
    ;; Generic search function, could be extended with various traversal order
    search: function [
        { 
            Search the tree and collect nodes matching a given function.
            Per default, perform a depth first search to the left
        }
        node [block!]
        cond [function!]
        return: [block!] ; block possibly empty with the matched nodes
    ][
        res: copy []
        _search-rec node :cond res
        return res
    ]
    _search-rec: function [
        node [block!]
        cond [function!]
        res [block!]
    ][
        switch node/node-type [
            node1 [ 
                _search-rec node/child :cond res
            ]
            node2 [ 
                _search-rec node/left :cond res
                _search-rec node/right :cond res
            ]
        ]
        cd: attempt [ cond node ]
        if cd [
            append/only res node
        ]
    ]

    ; small debug string
    as-string: function [
        node [block!]
        return: [string!]
    ][
        assert (node? node) "as-string - expecting node value"
        buf: make string! 10
        append buf node/label
        if not none? node/value [
            append buf ":"
            append buf to-string node/value
        ]
        return buf
    ]
    ; A version of probe
    ; You would like to use probe instead, as well as mold or other regular words of the language.
    ; However think it twice, unless you implement a fallback strategy. If probe is defined here, 
    ; any code bound against this context will use it. So it should implement the same interface
    ; (and capabilities) as the probe that lies in the global context. If you merely want to provide
    ; a probe-like feature for this particular object and context, better have it named differently 
    ; so as to avoid any conflicts. A feature of the language could be the ability to distinguish
    ; between the internals of an object or contrext from its interface. Distinguish between the probe
    ; used internally that would be bound regularly against the global context, from the probe defined
    ; in the object itself that may be referred by others. }
    myprobe: function [
        "Prints out the node"
        node [any-type!]
    ][
        print mymold node
    ]
    mymold: function [
        "Debug string"
        node [any-type!]
        return: [string!]
    ][
        if not node? node [ return mold node ]
        buf: make string! 10
        _mymold-rec buf node
        return buf
    ]
    _mymold-rec: function [
        "Helper function for mymold"
        buf [string!]
        node [block!]
    ][
        switch node/node-type [
            node0 [
                append buf "["
                append buf as-string node
                append buf "]"
                exit
            ]
            node1 [ 
                append buf "["
                append buf as-string node
                append buf " "
                _mymold-rec buf node/child
                append buf "]"
                exit
            ]
            node2 [
                append buf "["
                append buf as-string node
                append buf " "
                _mymold-rec buf node/left
                append buf " "
                _mymold-rec buf node/right
                append buf "]"
                exit
            ]
        ]
        do make error! "_mymold-rec - expecting node value"
    ]
    myprint: function [
        "Prints out the node"
        node [any-type!]
    ][
        print myform node
    ]
    myform: function [
        node [any-type!]
        return: [string!]
    ][
        if not node? node [ return form node ] ; if myform were to be multi-usage
        buf: make string! 250
        _myform-rec buf node
        return buf
    ]
    _myform-rec: function [
        buf [string!]
        node [block!]
    ][
        switch node/node-type [
            node0 [
                switch/default node/label [
                    value [ 
                        append buf to-string node/value
                    ]
                    var [
                        append buf "#"
                        append buf to-string node/value
                        if all [ 
                            node/extra ; expression
                            node/extra/computed? ; only if computed
                            node/extra/stacked? ; only if stacked
                            node/extra/node ; root of expression
                        ][
                            append buf "[ "
                            _myform-rec buf node/extra/node
                            append buf " ]"
                        ]
                    ]
                ][
                    k: select keys node/label
                    append buf either block? k [ k/5 ] [ node/label ]
                    if not none? node/value [
                        append buf ":"
                        append buf to-string node/value
                    ]
                ]
                exit
            ]
            node1 [
                k: select keys node/label
                either block? k [
                    with-paren: not any [
                        equal? k/6 ")"
                        find [subexp value] node/child/label
                        find [subexp] node/label
                    ]
                    append buf k/5
                    if with-paren [ append buf "(" ]
                    _myform-rec buf node/child
                    if with-paren [ append buf ")" ]
                    append buf k/6
                ][
                    append buf node/label
                    if not none? node/value [
                        append buf ":"
                        append buf to-string node/value
                    ]
                    append buf "("
                    _myform-rec buf node/child
                    append buf ")"
                ]
                exit
            ]
            node2 [
                _myform-rec buf node/left
                append buf " "
                k: select keys node/label
                either block? k [
                    append buf k/5
                ][
                    append buf node/label
                ]
                if not none? node/value [
                    append buf ":"
                    append buf to-string node/value
                ]
                append buf " "
                _myform-rec buf node/right
                exit
            ]
        ]
        do make error! rejoin ["_myform-rec - unknown node type:" node/node-type]
    ]

    ; compute - all this for that ...
    compute: function [
        "Compute the node value"
        node [block!]
        return: [number!]
    ][
        assert ( node? node ) "compute - expecting node value"
        v: _compute-rec node
        return v
    ]
    
    _compute-rec: function [
        node [block!]
        return: [number!]
    ][
        res: none
        cmd: none
        switch node/node-type [
            node0 [
                switch/default node/label [
                    value [ 
                        res: node/value
                    ]
                    var [
                        ; if var, the value returned is the value from the target expression
                        either all [
                            node/extra
                            node/extra/val
                        ][
                            res: node/extra/val ; val to get the computed value
                        ][
                            res: none
                        ]
                    ]
                ][
                    ; assume constant to evaluate
                    cmd: in funcs node/label
                ]
            ]
            node1 [
                either find [subexp] node/label [ ; var or subexpression - just transfer to the child
                    res: _compute-rec node/child
                ][
                    cmd: in funcs node/label
                    if cmd [
                        either node/value [ ; possible option to pass to the command
                            cmd: compose [ (cmd) ( _compute-rec node/child ) ( node/value ) ]
                        ][
                            cmd: compose [ (cmd) ( _compute-rec node/child ) ]
                        ]
                    ]
                ]
            ]
            node2 [
                cmd: in funcs node/label
                if cmd [
                    either node/value [ ; possible option to pass to the command
                        cmd: compose [ (cmd) ( _compute-rec node/left ) ( _compute-rec node/right ) ( node/value ) ]
                    ][
                        cmd: compose [ (cmd) ( _compute-rec node/left ) ( _compute-rec node/right ) ]
                    ]
                ]
            ]
        ]
        ; evaluate the resulting command if any
        return case [
            res [
                if debug [ 
                    print [ "Returns value" res "for node:" tree/as-string node ]
                ]
                res
            ]
            cmd [
                if debug [ 
                    print [ "About to execute" cmd "for node:" tree/as-string node ]
                ]
                res: do cmd
            ]
            true [
                do make error! rejoin [ "Impossible to compute node:" tree/as-string node ]
            ]
        ]
    ]

]
;tree
;]

;--------------------------------------------------------------------
; Helper stack used when parsing
;--------------------------------------------------------------------

; A stack is used during the parsing for collecting the values (in lieu of collect/keep).
; Should not be necessary, however collect/keep does not cleanup values in case of backtrack
; and my poor grammar require such backtracking. Therefore I do it by hand.
;comment [
stack: context [

    type: 'stack

    ; the underlying container that is a regular serie
    s: copy []

    ; clone self
    clone: function [ return: [object!] ][
        t: make self []
        t/s: copy []
        return t
    ]

    ; init
    init: function [][
        clear self/s
    ]

    ; Avoid using the "same" words as in the global context otherwise infinite loop.
    ; The language would benefit an outer or super keyword to access the enclosing context
    is-empty: function [
        "Empty ?"
        return: [logic!]
    ][
        return empty? self/s
    ]

    ; process the given rule
    rule: function [
        "Handle a rule, and setup the stack accordingly"
        /enter "Enter the given rule"
            name [word!] "Name of the rule"
            pos [series!] "Current position for debug"
        /fail "Rule has failed, backtrack the stack"
        /keep "Rule has succeded accept the last changes"
    ][
        ; check args
        nb: 0
        if enter [ nb: nb + 1 ]
        if fail [ nb: nb + 1 ]
        if keep [ nb: nb + 1 ]
        assert (nb == 1) "Either enter, fail or keep refinement !"
        ; enter a rule => add a separator to mark the rule entry
        if enter [
            if debug [ print-rule '> name pos ]
            append self/s 'sep
            append self/s name
            exit
        ]
        ; remove last sep and keep collected nodes
        if keep [
            t: find/last self/s 'sep
            name: second t
            remove remove t
            if debug [ print-rule '= name [] ]
            exit
        ]
        ; remove last sep and get rid of top nodes
        if fail [
            t: find/last self/s 'sep
            name: second t
            clear t
            if debug [ print-rule 'x name [] ]
            exit
        ]
        exit
    ]

    ; push something in the stack
    push: function [
        "Push a value or many values into stack"
        value [any-type!]
        /many 
    ][
        either many [
            append self/s value
        ][
            append/only self/s value
        ]
    ]

    ; retrieve something from the stack
    pop: function [
        "Returns the last value found"
        return: [any-type!] ; "Last value or none if no value left"
    ][
        return take/last self/s
    ]

    ; just a peek
    top: function [
        "Get top of stack without destacking"
        return: [any-type!]
    ][
        return last self/s ; last takes care of void serie
    ]

    ; another peek
    top-1: function [
        "Get top of stack - 1"
        return: [any-type!]
    ][
        if (length? self/s) <= 1 [ return none ]
        return pick self/s ( (length? self/s) - 1) ; this fellow does not take care of void serie !
    ]

    ; indentation for debug
    ident: function [
        "Returns padding string for stack display"
        return: [string!]
    ][
        ; count nb of visited rules in the stack (nb of sep)
        a: self/s
        nb: 0
        until [
            a: find a 'sep
            if none? a [break]
            nb: nb + 1
            a: find/match a 'sep
            false
        ]
        ; generate corresponding padding string
        id: copy ""
        pad id nb
        return id
    ]

    ; print a rule with the proper identation
    print-rule: function [
        "Print rule"
        mark [word!]
        rule [word!]
        pos [series!]
    ][
        prin [ ident mark rule ]
        if not empty? pos [
            prin [" " mold pos]
        ]
        prin newline
    ]

    ; pretty-print the stack content
    myprobe: function [
        "Pretty print the stack"
    ][
        print self/mymold
    ]

    ; pretty-print string for debug
    mymold: function [
        "Returns a debug string"
        return: [string!]
    ][
        str: copy ""
        _mymold-rec str self/s
        return str
    ]

    ; recursive call for mymold
    _mymold-rec: function [
        "Pretty print the stack recursively into a string"
        buffer [string!]
        value [any-type!]
    ][
        if tree/node? value [
            append buffer tree/mymold value
            exit
        ]
        if block? value [
            append buffer "["
            if not empty? value [
                _mymold-rec buffer first value
                value: next value
                while [ not empty? value ] [
                    append buffer " "
                    _mymold-rec buffer first value
                    value: next value
                ]
            ]
            append buffer "]"
            exit
        ]
        if object? value [
            if find (words-of value) 'as-string [
                append buffer (value/as-string)
                exit
            ]
            append buffer mold value
            exit
        ]
        append buffer mold value
        exit
    ]

]
;stack
;]

;----------------------------------------------------------------------------
; Expr model core (for lexer, spacer, syntaxer)
;----------------------------------------------------------------------------
model-core: context [

    expr: object [

        uh34: none ; unique id for the type

        status: none
        source: none        ; source either a block of keys or a string!
        failed: none        ; index on source for the first non processed key or character
        tokens: copy []     ; tokens produced
        node: none          ; computed node tree

        ; some debug string
        source-as-string: function [return: [string!]] [ expr-source-as-string self ]
        failed-as-string: function [return: [string!]] [ expr-failed-as-string self ]
        node-as-string: function [return: [string!]] [ expr-node-as-string self ]
        tokens-as-string: function [return: [string! ]] [ expr-tokens-as-string self ]

        ; other functions directly implemented
        empty?: function [return: [logic!]][ global/empty? source ]
        failed?: function [return: [logic!]][ return not any [ none? failed tail? failed ] ]
        last-key: function [return: [lit-word!]][ return last source ]
        keys: function [return: [block!]][return source]
        ;restore-all-keys: function [ex [object!] keys [block!]][source: keys]
        valid?: function [return: [logic!]][ return not none? node ]

    ]

    ; Outputs a token buffer for debug
    expr-tokens-as-string: function [
        "Turn a token list into a string"
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'uh34 ) "Expects an expr object"
        tokens: ex/tokens
        buf: copy ""
        foreach t tokens [
            switch/default t/1 [
                'value [ append buf ( mold t/4 ) ]
                'var [
                    append buf keys/var/4
                    append buf ( mold t/4 ) ; var number
                ]
                'spacer [
                    k: select keys t/4
                    append buf ( either k [k/4]["?"] )
                    append buf ( int-as-subscript t/5 ) ; repetition
                ]
            ][
                ; other case const, unary, binary, paren => key value
                k: select keys t/4
                append buf ( either k [ k/4 ] ["?" ] )
            ]
        ]
        buf
    ]

    ; Convert an integer into a subscript number
    int-as-subscript: function [
        "Integer as subscript"
        i [integer!]
        return: [string!]
    ][
        str: to-string i
        res: make string! length? str
        foreach s str [
            case [
                all [ s >= #"0" s <= #"9" ] [ r: #"₀" - #"0" + s ]
                s == #"-" [ r: #"₋" ]
                s == #"+" [ r: #"₊" ]
                true [ r: #"?" ]
            ]
            res: append res r
        ]
        res
    ]

    ; helper function - outputs a buffer of keys
    keys-as-string: function [
        "Returns a key stream as a string to be displayed"
        buffer [block!]
        return: [string!]
    ][
        if not buffer [ return copy "" ]
        spacer: [
            s:
            [
                some 'ets-spacer |
                some 'efs-spacer |
                some 'ste-spacer |
                some 'sfe-spacer
            ]
            e:
            keep (
                nb: offset? s e
                t: s/1
                rejoin [keys/(t)/4 (either nb == 1 [""][ int-as-subscript nb]) ]
            )
        ]
        key: [
            copy w lit-word! keep ( 
                either k: select keys (w/1) [ k/4 ] [ "?" ]
            )
        ]
        rule: [ collect into res [ any [ spacer | key ] ] ]
        res: copy [""] ; make sure rejoin will produce a string
        success?: parse buffer rule
        either success? [rejoin res][ copy "" ]
    ]

    ; helper function - outputs a buffer of keys
    expr-keys-as-string: function [
        "Returns a key stream as a string to be displayed"
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'uh34 ) "Expects an expr object"
        buffer: ex/source
        if any [ not buffer empty? buffer ] [ return copy ""]
        if string! == type? buffer [ return buffer ]
        return keys-as-string buffer
    ]

    ; well formed string of the computed node
    expr-node-as-string: function [
        ex [object!]
        return: [string!] ; the well formed expression for final display
    ][
        assert ( in ex 'uh34 ) "Expects an expr object"
        either none? ex/node [
            copy ""
        ][
            tree/myform ex/node
        ]
    ]

   ; nice string output for the source
    expr-source-as-string: function [
        ex [object!]
        return: [string!] ; the symbol list
    ][
        assert ( in ex 'uh34 ) "Expects an expr object"
        switch/default type? ex/source [ 
            #[block!] [ keys-as-string ex/source ]
            #[string!] [ ex/source ]
        ] [ copy "" ]
    ]

    ; failed symbols as string - used for displaying in the recalculator beneath the result
    expr-failed-as-string: function [
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'uh34 ) "Expects an expr object"
        switch/default type? ex/failed [ 
            #[block!] [ keys-as-string ex/failed ]
            #[string!] [ ex/failed ]
        ] [ copy "" ]
    ]

]

;----------------------------------------------------------------------------
; Lexical analysis : analyse an input string or key buffer and produces 
; a token stream
;
; It is implemented as a separate context from expr though it could be 
; within it. In practice, that does not make much difference, apart from
; few path calls as they are all singletons.
;----------------------------------------------------------------------------
;comment [
lexer: context [

    debug: false

    type: 'lexer

    run: function [
        "Run the lexer on the given expression"
        target [object! block! string!] "Expression as an expr object, a string or a block containing the list of keys"
        return: [object!] ; Returns an expr object after update of /status /source /tokens /failed
    ][
        ; inialise a place holder for the computation if not provided
        ex: none
        either object! == type? target [
            ex: target
        ][
            ex: make model-core/expr []
            ex/source: target
        ]

        ; different rules are used according to the buffer type, either block! of keys (lit-word! values)
        ; or string to parse - could use compose instead of a get-word
        rule: either block! == type? ex/source [ :token-keys ][ :lexical-str ]

        ; as function is used, set-words are locals, therefore always use self to modify fields
        ; of self (i.e. set-word!) if using function ( @ZWT words in self should probably not be forced as local even
        ; by function ! )
        self/lst: none

        tokens: :ex/tokens
        ex/status: parse ex/source [ collect into tokens rule ]
        ex/failed: either ex/status [ none ] [ lst ]

        if debug [
            print "Lexer run:"
            print ["status:" ex/status]
            print ["source:" mold ex/source]
            print ["tokens:" mold ex/tokens]
            print ["failed:" mold ex/failed]
        ]

        return ex
    ]

    ;---------------------------------------------------------------------------------------
    ; Key oriented parsing rules - for string rules see below
    ;---------------------------------------------------------------------------------------

    ;; TOKEN FORMAT
    ;; tokens are produced as small blocks that have the following format :
    ;; t/1 : token type as word - either 'unary, 'binary, 'spacer, 'var, 'constant, 'paren, 'value
    ;; t/2 : start position of the token in the input buffer (string or key list)
    ;; t/3 : end position of the token in the input buffer (one step ahead)
    ;; t/4 : optional value depending on the type 
    ;;     for 'unary or 'binary, the corresponding operator or function 'add, 'multiply etc
    ;;     for 'paren, either 'paren-l or 'paren-r
    ;;     for 'spacer, either 'ets-spacer, 'efs-spacer, 'ste-spacer, 'sfe-spacer
    ;;     for 'var, the variable number
    ;;     for 'value, the value number
    ;;     for 'constant, the constant word 'E, 'PI etc.

    ; Make sure the following words that are used in the parse rules resolve in words bound to
    ; the lexer object ! Otherwise they may spill out in the global context, which you may not want.
    ; This is another part of Red that does not feel right - you have to chase the variables that 
    ; pop up from nowhere, that might be shared and modified without any warning.
    ; A context should catch everything that has not been declared as global. Like function does
    ; for its locals.
    e: f: n: s: none

    ; last parsed key
    lst: none

    ; high level parse rule for the tokenization
    ; pretty dumb rule in fact - maybe parse was not that useful here...
    token-keys: [
        lst:
        any [ number-key | paren-key | binary-key | spacer-keys | variable-key | constant-key | unary-key ] 
        lst: ; a handy catch all strategy for failed inputs - just mark its end
    ]

    ; unary operator
    unary-key: [
        s: op-unary e: ; another simple strategy, here to separate pure grammar rules (here op-unary) from action rules
        ; the same effect could be achieved using callback instead - but not tested
        keep ( compose [ 'unary (index? s) (index? e) (s/1) ] )
    ]

    ; dynamic parse rule generation
    ; the following parse rule is generated dynamically with a do block that is runned when the context is built !
    ; pretty handy and neat
    op-unary: do [

        ;; here a functin defined within the do block to make sure the local variables are contained
        ;; do does not auto-protect - could be an added refinement to it
        f: function [][
            b: copy []
            foreach v values-of keys [
                if 'unary == v/2 [
                    append b to-lit-word v/1
                    append b '|
                ]
            ]
            take/last b
            if debug [ print ["op-unary:" mold b ] ]
            b
        ]
        f

    ]

    ; binary operator
    binary-key: [
        s: op-binary e:
        keep ( compose [ 'binary (index? s) (index? e) (s/1) ] )
    ]
    op-binary: [ op-binary-add | op-binary-mult | op-binary-power ]
    op-binary-add: [ 'add | 'subtract ]
    op-binary-mult: [ 'multiply | 'divide | 'modulo | 'remainder ]
    op-binary-power: [ 'power | 'square | 'exps ]

    ; parenthesis
    paren-key: [
        s: paren e: 
        keep ( compose [ 'paren (index? s) (index? e) (s/1) ] )
    ]
    paren: [ 'paren-l | 'paren-r ]

    ; spacer
    spacer-keys: [
        s: spacer e:
        keep ( compose [ 'spacer (index? s) (index? e) (s/1) (offset? s e) ] )
    ]
    spacer: [ 
        [
            some 'ets-spacer |
            some 'efs-spacer |
            some 'ste-spacer |
            some 'sfe-spacer
        ] 
    ]

    ; variable
    variable-key: [
        s: variable e:
        keep ( compose [ 'var (index? s) (index? e) (keys-to-number n: copy/part next s e) ] )
    ]
    variable: [ 'var integer ]

    ; constant
    constant-key: [
        s: constant e: 
        keep ( compose [ 'constant (index? s) (index? e) (s/1) ] )
    ]
    constant: [ 'E | 'PI ]

    ; numbers
    number-key: [
        s: number e:
        keep ( compose [ 'value (index? s) (index? e) (keys-to-number n: copy/part s e) ] )
    ]
    number: [ integer opt decimal | decimal ]
    integer: [ some digit ]
    decimal: [ 'decimal-separator some digit ]
    digit: [ 'n0 | 'n1 | 'n2 | 'n3 | 'n4 | 'n5 | 'n6 | 'n7 | 'n8 | 'n9 ]

    ; helper function to compute a number from a key buffer
    keys-to-number: function [
        "Helper function to converts a buffer of keys into a number"
        keys [block!]
        return: [number!]
    ][
        ; just map the digit keys into characters and let load do the dirty job
        str: copy ""
        if keys/1 == 'decimal-separator [ ; add missing leading 0
            append str #"0"
        ]
        foreach k keys [
            c: select [
                n0 #"0"
                n1 #"1"
                n2 #"2"
                n3 #"3"
                n4 #"4"
                n5 #"5"
                n6 #"6"
                n7 #"7"
                n8 #"8"
                n9 #"9"
                decimal-separator #"."
            ] k
            either c [ append str c ][
                do make error! reduce [ "Unexpected key for a number : " k]
            ]
        ]
        ; if overflow, load will trigger its own error
        nb: load str 
        return nb
    ]

    ;---------------------------------------------------------------------------------------
    ; Character oriented parsing rules - convert a character stream into a token stream
    ;---------------------------------------------------------------------------------------

    ; other words that are used in these parse rules
    ; e: f: m: n: s: none
    t: none

    ; high level parse rule for the lexical analysis on strings
    lexical-str: [
        lst: 
        any [
            operator-str | delim-op-left-str | delim-op-right-str | 
            absolute-str | spacer-str | paren-str | var-str | number-str
        ]
        lst:
    ]

    ; operators : another illustration of a dynamic parse rule but what a mess 
    ; when using compose and targeting a block that also works with parenthesis !
    operator-str: do [

        f: function [/extern s e ][
            ; retrieve all operators
            ops: copy []
            foreach k values-of keys [
                if all [
                    find [unary binary constant] k/2
                    not find [absolute round ceil floor] k/1 ; specific rule
                ][
                    m: either k/5 <> "" [k/5][k/6] ; string value left or right
                    if m == "" [
                        if debug [ print [ "Unknown string value for " k/1 ] ]
                        continue
                    ]
                    append/only ops reduce [ k/1 k/2 m ]
                ]
            ]
            ; sort out in reverse alphabetical order to make sure
            ; longest strings are considered first - with parse first matching rule wins !
            sort/compare ops ( function [x y] [ x/3 > y/3 ] )
            ; outputs the resulting rule
            rules: copy []
            foreach o ops [
                p: to-block to-lit-word o/2
                p: append p [ (index? s) (index? e) ]
                p: append p to-lit-word o/1
                p: compose/deep [ compose [ (p) ] ]
                append rules compose [
                    s: (o/3) e: keep ( to-paren p ) | 
                ]
            ]
            take/last rules ; remove last |
            if debug [ print ["operator-str:" mold rules] ]
            rules
        ]
        f
    ]

    ; special case of absolute token that is also a delimiter but identical, on left and right
    ; desambiguiation in spacer-handler phase
    absolute-str: [
        s: "|" e:
        keep ( compose ['paren (index? s) (index? e) 'absolute? ] )
    ]

    ; special case of unary operators that also work as delimiters like parenthesis
    ; this is the case of round, ceiling, floor
    ; this is handled by producing a unary operator token and paren tokens
    ; it cannot distinguish however between parenthesis. If these are well balanced 
    ; it is not an issue, if they are not it may pick a parenthesis that is not the one intended.
    delim-op-left-str: do [
        f: function [ /extern e s t ][
            b: compose/deep [
                s: 
                [ 
                    (keys/round/5) ( to-paren [ t: 'round ] )
                    | (keys/ceil/5) ( to-paren [ t: 'ceil ] )
                    | (keys/floor/5) ( to-paren [ t: 'floor ] )
                ]
                e:
            ]
            append b [
                keep ( compose [ 'unary (index? s) (index? e) (to-lit-word t) ])
                keep ( compose [ 'paren (index? e) (index? e) 'paren-l ]) ; insert a supplementary left parenthesis
            ]
            if debug [ print [ "delim-op-left-str:" mold b] ]
            b
        ]
        f
    ]
    delim-op-right-str: do [
        f: function [ /extern e s ][
            b: compose/deep [
                s:
                [
                    (keys/round/6)
                    | (keys/ceil/6)
                    | (keys/floor/6)
                ]
                e:
            ]
            append b [
                keep ( compose [ 'paren (index? s) (index? s) 'paren-r ]) ; insert a right parenthesis
            ]
            if debug [ print [ "delim-op-right-str:" mold b] ]
            b
        ]
        f
    ]

    ; example of pure static rule
    paren-str: [
        s: "(" e: keep ( compose [ 'paren (index? s) (index? e) 'paren-l] )
        |
        s: ")" e:  keep ( compose [ 'paren (index? s) (index? e) 'paren-r] )
    ]

    ; spacer (dynamic rule - same strategy)
    spacer-str: do [
        f: function [ /extern e s n ] [
            spacers: copy []
            append/only spacers reduce [ keys/ets-spacer/1 keys/ets-spacer/5 ]
            append/only spacers reduce [ keys/efs-spacer/1 keys/efs-spacer/5 ]
            append/only spacers reduce [ keys/ste-spacer/1 keys/ste-spacer/5 ]
            append/only spacers reduce [ keys/sfe-spacer/1 keys/sfe-spacer/5 ]
            rules: copy []
            foreach spc spacers [
                p: copy [ 'spacer (index? s) (index? e) ]
                append p to-lit-word spc/1
                append p [ ( either empty? n [1][ subscript-as-int n ] ) ]
                p: compose/deep [ compose [ (p) ] ]
                append rules compose [
                    s: (spc/2) copy n any subscript-digit-str e: keep ( to-paren p ) | 
                ]
            ]
            take/last rules ; remove last |
            if debug [ print ["spacer-str:" mold rules] ]
            rules
        ]
        f
    ]

    ; Convert a subscript string into an integer value
    subscript-as-int: function [
        "Subscript to integer"
        str [string!]
        return: [integer!]
    ][
        res: copy ""
        foreach s str [
            case [
                all [ s >= #"₀" s <= #"₉" ] [ append res ( s - #"₀" + #"0" ) ]
                s == #"₋" [ append res #"-" ]
                s == #"₊" [ append res #"+" ]
            ]
        ]
        return to-integer res
    ]

    ; subscript number as string
    ; parse rules may be charset !
    subscript-digit-str: charset [#"₀" - #"₉"]

    ; variable
    var-str: [
        s: "#" integer-str e: 
        keep (
            n: copy/part (next s) e
            n: load n
            compose [ 'var (index? s) (index? e) (n) ] 
        )
    ]

    ; number - integer or float
    number-str: [
        s:
        [ 
            opt "-" 
            [ 
                integer-str opt decimal-str opt exposant-str
                |
                decimal-str opt exposant-str
            ]
        ]
        e:
        keep (
            n: copy/part s e
            replace/all n keys/decimal-separator/4 "."
            if (find/match n ".") [ insert n "0"]
            if (find/match n "-.") [ insert (next n) "0"]
            n: load n ; once again lets leave load do the dirty job
            compose [ 'value (index? s) (index? e) (n) ]
        )
    ]
    integer-str: [ some digit-str ]

    ; dynamic rule for the decimal part using compose
    decimal-str: do [
        f: function [][
            b: compose [ (keys/decimal-separator/4) some digit-str ]
            if debug [ print [ "decimal-part-str:" mold b] ]
            b
        ]
        f
    ]

    exposant-str: [ ["e" | "E"] opt "-" non-zero-digit-str any digit-str ]
    non-zero-digit-str: charset "123456789"
    digit-str: union non-zero-digit-str charset #"0"

]
;lexer
;]

;------------------------------------------------------------------
; Spacer handler
;------------------------------------------------------------------
{

    A spacer is one or more consecutive delimiters that are added to an expression as a shortcut 
    for entering parenthesis. Instead of entering well matching parenthesis within the expression,
    the user can enter a spacer at a specific location and have the matching parenthesis positioned
    automatically at a matching position that depends on the number of times the spacer was entered.
    
    Depending on the location of the fixed parenthesis, and the direction of the moving parenthesis, 
    four possible spacers can be defined :
    1- right parenthesis is fixed (at the spacer location) and the left parenthesis is moved from this
    position to the left until the start of the expression is reached ( end to start spacer - ETSS - (â†â¦† )
    2- right parenthesis is also fixed, but the left parenthesis move the otherway round, starting
    at the beginning of the expression to the end is reached ( end from start spacer - EFSS - (â†’â¦† ),
    3- left parenthesis is fixed at the expression start, and right parenthesis is moving from left to
    right until its end ( start to end spacer - STES )
    4- left parenthesis is fixed at the expression start, and right parenthesis is moving from right
    to left until the start is reached ( start from end spacer - SFES ) )

    1- End to start spacer (ETSS)
    
    When an ETSS is entered, a right parenthesis is added at the corresponding location. The matching left 
    parenthesis is added automatically at a chosen location that depends on the length of the spacer 
    (the number of times this spacer was repeated). The wider the spacer is, the farther away to the left 
    the left parenthesis is moved :
    
    - Possible locations for the ETSS are possible location for any location for a right parenthesis
    within the expression, therefore on the right side of a value, a sub-expression, or a unary operator
    in postfix position or that could be determined to be so.

    - Possible locations for the matching left parenthesis (the moving one) are on the left side of a value, 
    a sub-expression, a unary operator that is in infix position or that could be determined to be so.
    
    - If the spacer is one space long, the left parenthesis is added at the first possible location to the left.
    If it is two spaces long, it is added at the next available position, and so on until the start of 
    the expression is reached. Additional spacers are ignored. For instance:
        - 1*2*3*4⦆ => 1*2*3*(4) - 1 spacer
        - 1*2*3*4⦆⦆ => 1*2+(3*4) - 2 spacers
        - 1*2*3*4⦆⦆⦆ => 1*(2+3*4) - 3 spacers
        - 1*2*3*4⦆⦆⦆⦆ => (1*2+3*4) - 4 spacers
        - 1*2*3*4⦆⦆⦆⦆ => (1*2+3*4) - 5 spacers

    - If the ETSS is initiated within a sub-expression, the ETSS left parenthesis stops at the 
    sub-expression start. For instance :
        - 1*2*(3*4*5⦆) => 1*2*(3*4*(5)) - still within a sub-expression
        - 1*2*(3*4*5⦆) => 1*2*(3*(4*5)) - still within a sub-expression
        - 1*2*(3*4*5⦆⦆⦆ => 1*2*(3*4*5) - sub-expression boundary reached
        - 1*2*(3*4*5⦆⦆⦆⦆ => 1*2*(3*4*5) - same

    2- End from start spacer (EFSS)

    The EFSS works similary to the ETSS except the left parenthesis, that is moving, starts at the begining
    of the expression or sub-expression, and move towards the right parenthesis. Otherwise the same rules apply.

    3- Start to end spacer (STES)
    
    For the STES, the fixed parenthesis is the left one and it is positionned at the start of the current 
    expression or sub-expression. The moving parenthesis is the right one and it moves from left to right, 
    away from the starting position and towards the end position. For instance, using the same expression 
    as before: 
        - 1*2*3*4⦅ => (1)*2*3*4 - 1 spacer
        - 1*2*3*4⦅⦅ => (1*2)*3*4 - 2 spacers
        - 1*2*3*4⦅⦅⦅ => (1*2+3)*4 - 3 spacers
        - 1*2*3*4⦅⦅⦅⦅ => (1*2+3*4) - 4 spacers
        - 1*2*3*4⦅⦅⦅⦅⦅ => (1*2+3*4) - 5 spacers
    
    - Possible locations for the STES are the same as ETSS.
    
    4- Start from end spacer (SFES)

    The same as STES except the moving right parenthesis starts from the end and move backwards towards 
    the expression start.

    5- Implementation

    The spacers are handled between the lexical analysis and the building of the final expression, 
    as it is easier to do likewise. A quick parsing of the expression determines where the parenthesis
    can be located (left or right). Then spacers are processed one at a time from left to right, as entered.
    Each spacer determines a new set for parenthesis that are added to the expression. Subsequent spacers
    are handled in a similar way.

}
;comment [
spacer: context [

    debug: false

    type: 'spacer

    stack: none

    ; Handle spacers
    ; same interface is used as for the lexer and syntaxer, taking an expression
    ; object and returning it back once modified
    run: function [
        "Handle spacers within the given token list"
        ex [object!] "Expression with the token stream produced by the lexical analysis"
        return: [object!] ; returns the expression after modifying /status /tokens /discarded
    ][
        source: ex/source
        tokens: ex/tokens
        status: failed: none

        ; creates the stack if first run
        ; here recalculator/stack is used to distinguish the object prototype from the local instance
        ; another situation where super as a keyword might be useful
        if none? self/stack [ self/stack: recalculator/stack/clone ]
        stack/init

        ; make sure there is at least one spacer or an absolute? to handle
        ; otherwise just pass along
        found?: false
        foreach tk tokens [
            switch tk/1 [ 
                'spacer [ ; here it the lit-word 'spacer that is meant
                    found?: true
                    break
                ]
                'paren [
                    if tk/4 == to-lit-word 'absolute? [
                        found?: true
                        break
                    ]
                ]
            ]
        ]
        either not found? [
            if debug [ 
                print "Spacer - nothing to process"
            ]
            status: true
        ][

            ; parse the stream of tokens to compute possible insertion points for parenthesis
            ; doing so also identify positions of absolute? tokens
            self/lst: none
            status: parse tokens sp-root

            ; if not entirely parsed, keeps failed key entry and clear all failed tokens
            if all [ not status lst not empty? lst ] [
                failed: at source lst/1/2
                clear lst
            ]

            if debug [
                print ["Spacer - parsing:" res ]
                print "Spacer - stack after parsing..."
                stack/myprobe
                print ["Last tokens:" mold lst ]
            ]

            ; if stack is void (analysis completly failed), nothing to work on - just leave
            either stack/is-empty [
                if debug [
                    print ["Stack after parsing for spacers is void!"]
                ]
                status: false
            ][

                ; the stack after the parse contains the spacers entered by the user and the locations
                ; where to insert additional parenthesis - see parsing rules below
                ; 
                spc: stack/s

                ; runs through the stack, looking for spacers provided by the user
                until [
                    process?: true
                    inserted?: false
                    switch/default spc/1/t [
                        ; handle the different types of spacers 
                        ; and insert corresponding parenthesis directly in the stack (not in the target buffer of tokens yet)
                        ets-spacer [ inserted?: _interval-ets spc ]
                        efs-spacer [ inserted?: _interval-efs spc ]
                        ste-spacer [ inserted?: _interval-ste spc ]
                        sfe-spacer [ inserted?: _interval-sfe spc ]
                        absolute-l absolute-r [ true ]
                    ][
                        process?: false
                    ]
                    if process? and debug [ 
                        print [ "Spacer - processed:" spc/1/t "result:" inserted? ]
                    ]
                    if inserted? [
                        spc: next next spc ; accounts for the two newly added parenthesis in the stack
                    ]
                    spc: next spc
                    tail? spc
                ]

                if debug [
                    print "Spacer - stack after spacers processing..."
                    stack/myprobe
                ]

                ; modify the target buffer of tokens adding paren-l/paren-r for the newly
                ; created sub-expression.
                ; modifications are performed backwards from the end or the last parsed token
                ; to the start of the buffer. This to account for the modification of the indexes
                ; as the tokens are added or removed from the stream (i.e. a serie is an index 
                ; on an underlying list but if you change modify series item before it - the serie gets shifted)
                spc: tail spc
                until [
                    spc: back spc
                    switch spc/1/t [
                        spacer-l [
                            if spc/1/a [
                                i: at tokens spc/1/p
                                insert/only i compose [
                                    'paren
                                    (i/1/2) ; retrieve the next token start
                                    (i/1/2)
                                    'paren-l
                                ]
                            ]
                        ]
                        spacer-r [
                            if spc/1/a [
                                i: at tokens spc/1/p
                                p: back i
                                insert/only i compose [
                                    'paren
                                    (p/1/3) ; retrieve the last token end
                                    (p/1/3)
                                    'paren-r
                                ]
                            ]
                        ]
                        ; also correct absolute? markes - see parse rule below sp-absolute?
                        absolute-l [
                            i: at tokens spc/1/p
                            ; retarget absolute? as paren-l
                            i/1/4: to-lit-word 'paren-l
                            ; add just before new unary operator token for 'absolute
                            insert/only i compose [
                                'unary
                                (i/1/2) ; the next token start
                                (i/1/2)
                                'absolute
                            ]
                        ]
                        absolute-r [
                            ; retarget absolute? as paren-r
                            i: at tokens spc/1/p
                            i/1/4: to-lit-word 'paren-r
                        ]
                        ; get rid of the spacers in the buffer of tokens (might be kept and just ignored 
                        ; at the analysis phase though)
                        ets-spacer efs-spacer ste-spacer sfe-spacer [
                            remove (at tokens spc/1/p)
                        ]
                    ]
                    head? spc
                ]
                status: either status == false [ false ] [ true ]
            ]
        ]

        ex/status: status
        if failed [ ex/failed: failed ]

        if debug [
            print "Spacer - results"
            print ["status:" ex/status]
            print ["source:" mold ex/source]
            print ["failed:" mold ex/failed]
            print ["tokens:" mold ex/tokens]
        ]

        return ex
    ]

    ;; take care of ambiguous absolute (absolute?) that may have been emitted by
    ;; the lexer when analyzing a string. The character | serves two purposes : 
    ;; it is marker for the operation and a delimiter either opening or closing for
    ;; the value or the subexpression on which to perform the operation;
    ;; to resolve that, the buffer is scanned for the presence of absolute? and modify
    ;; them as absolute - parent-l for an openin absolute? and parent-r for a closing absolute

    _new-subexpression: function [
        "Helper function for creating new sub-expression markers to be added to the target buffer"
        left [block!] "left insertion point"
        right [block!] "right insertion point"
        lvl [integer!] "level for the new sub-expression"
    ][
        ; add new spacers with active state and matching level
        left: insert/only (next left) compose [
            t: spacer-l l: (lvl) p: (left/1/p) a: (true)
        ]
        left: back left
        right: next right ; shift right to account for the inserted spacer
        right: insert/only right compose [ 
            t: spacer-r l: (lvl) p: (right/1/p) a: (true)
        ]
        right: back right
        ; increase the parenthesis level of the newly enclosed area, from left to right
        n: left
        until [
            n/1/l: n/1/l + 1
            n: next n
            n == right
        ]
        right/1/l: right/1/l + 1
        exit
    ]

    _interval-ets: function [
        "Computes an ets spacer and inserts corresponding parenthesis in the stack"
        spc [block!]
        return: [logic!] ; true if success
    ][
        offset: spc/1/o
        lvl: spc/1/l ; current level of parenthesis
        ; search first right parenthesis from current position backwards
        ; stop if level changes or head is reached
        right: spc
        until [
            right: back right
            any [ 
                right/1/t == 'spacer-r
                right/1/l <> lvl
                head? right
            ]
        ]
        if not [ right/1/t == 'spacer-r and right/1/l == lvl ] [
            return false
        ]
        ; search left parenthesis from right parenthesis backwards
        ; match found if same level and enough positions considered, 
        ; or level decreases, or head is reached
        left: none
        ll: right
        until [
            ll: back ll
            ; match found, decrease offset
            if all [ 
                ll/1/l == lvl
                ll/1/t == 'spacer-l
            ][
                left: ll
                offset: offset - 1
            ]
            ; quit if no more position to consider
            any [ 
                zero? offset
                ll/1/l < lvl 
                head? ll
            ]
        ]
        ; retain last position found, unless none was found
        if none? left [
            return false
        ]
        ; insert the two new parenthesis
        _new-subexpression left right lvl
        return true
    ]

    _interval-efs: function [
        "Computes an efs spacer and inserts corresponding parenthesis"
        spc [block!]
        return: [logic!]
    ][
        offset: spc/1/o
        lvl: spc/1/l ; current level of parenthesis
        ; search first right parenthesis backwards from current position
        right: spc
        until [
            right: back right
            any [ 
                right/1/t == 'spacer-r
                right/1/l <> lvl
                head? right
            ]
        ]
        if not [ right/1/t == 'spacer-r and right/1/l == lvl ] [
            return false
        ]
        ;; get to the begining of the current sub-expression
        ll: right
        until [
            ll: back ll
            any [ head? ll ll/1/l < lvl ]
        ]
        if ll/1/l < lvl [
            ll: next ll
        ]
        ; search left parenthesis
        left: none
        while [ all [ offset > 0 (offset? ll right) > 0 ] ] [
            if all [ 
                ll/1/l == lvl
                ll/1/t == 'spacer-l 
            ][
                left: ll
                offset: offset - 1
            ]
            ll: next ll
        ]
        ; retain last position found, unless none was found
        if none? left [
            return false
        ]
        ; insert the two new parenthesis
        _new-subexpression left right lvl
        return true
    ]

    _interval-ste: function [
        "Computes an ste spacer and inserts corresponding parenthesis"
        spc [block!]
        return: [logic!]
    ][
        offset: spc/1/o
        lvl: spc/1/l ; current level of parenthesis
        ;; left positionned at the begining of the current sub-expression
        left: spc
        until [
            left: back left
            any [ left/1/l < lvl head? left ]
        ]
        if left/1/l < lvl [
            left: next left
        ]
        ;; assert left parenthesis
        if not all [
            left/1/t == 'spacer-l
            left/1/l == lvl
        ][
            return false
        ] 
        ; forward search looking for right parenthesis ('spacer-r)
        right: none
        rr: left
        until [
            rr: next rr
            ; possible match found
            if all [
                rr/1/l == lvl 
                rr/1/t == 'spacer-r
            ][
                right: rr
                offset: offset - 1
            ]
            ; quit if no more available positions
            any [ 
                zero? offset
                (offset? rr spc) <= 0
            ]
        ]
        ; retain last position found, unless none was found
        if none? right [
            return false
        ]
        ; insert the two new parenthesis
        _new-subexpression left right lvl
        return true
    ]

    _interval-sfe: function [
        "Computes an sfe spacer and inserts the corresponding parenthesis"
        spc [block!]
        return: [logic!]
    ][
        offset: spc/1/o
        lvl: spc/1/l ; current level of parenthesis
        ;; left positionned at the begining of the current sub-expression
        left: spc
        until [
            left: back left
            any [ left/1/l < lvl head? left ]
        ]
        if left/1/l < lvl [
            left: next left
        ]
        ;; assert left parenthesis
        if not all [
            left/1/t == 'spacer-l
            left/1/l == lvl
        ][
            return false
        ]
        ; backward search looking for matching right parenthesis ('spacer-r)
        right: none
        rr: spc
        until [
            rr: back rr
            ; possible match found
            if all [ 
                rr/1/l == lvl
                rr/1/t == 'spacer-r
            ][
                right: rr
                offset: offset - 1
            ]
            ; quit if no more position to consider
            any [ 
                zero? offset
                (offset? left rr) <= 0
            ]
        ]
        ; retain last position found, unless none was found
        if none? right [
            return false
        ]
        ; insert the two new parenthesis
        _new-subexpression left right lvl
        return true
    ]

    ;---------------------------------------------------------
    ; Parsing rules for the spacer handler
    ;---------------------------------------------------------

    ; make sure words used by parse rules are locals
    level: nb: pos: p: spacer: type: abs: none

    ; last parsed token
    lst: none

    ; input is a stream of tokens (see Lexer for the format description)
    sp-root: [
        (stack/init) (level: 1) ; initialise some variables local to the object
        lst: sp-expr lst: ; mark last token parsed
    ]
    sp-expr: [
        ; each rule start with a call to stack/rule/enter that marks the begining of the rule
        ; also serves for debugging purposes similar to parse/trace
        pos: (stack/rule/enter 'sp-expr pos)
        sp-term any [ sp-binary sp-term ]
        ; each rule ends with a call to stack/rule/keep that validates the collected items
        ; before to leave or a fallback rule that calls stack/rule/fail that rolls back 
        ; any items that might have been processed and collected since the beginning of the rule
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; term is values and unary operators chained together
    ; and separated by implict multiplications if need be
    ; unary operators at the beginning of the chain are considered as infix
    ; unary operators at the end of the chain are considered as postfix
    ; unary operators between values are either infix or postfix for the 
    ; sake of positionning the parenthesis
    sp-term: [
        pos: (stack/rule/enter 'sp-term pos)
        sp-left-parenthesis
        any [ sp-unary sp-left-parenthesis ] ; infix unaries
        sp-value sp-right-parenthesis
        any sp-other-term ; other terms
        any [ sp-unary sp-right-parenthesis ] ; postfix unaries
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; Binary and unary operators
    ; this is a simple rule that is only used as a matching rule in the previous rule
    ; here it says : expects a block, goes into it, check that first value is 'binary (or 'unary) and 
    ; then accept all the rest of the block
    sp-binary: [ into [ 'binary thru end ] ]
    sp-unary: [ into [ 'unary thru end ] ]

    ; other term with unaries in infix or postfix positions
    ; with the mechanism of start/end rule, you may backtrack from rules, which is not the 
    ; most efficient, but easier to follow
    ; here you have a distinct rule that explore the possibility of having some terms that may be
    ; either in infix or postfix position. However, you will only for the last one, once it has been
    ; parsed. Alternatively you could use ahead to check a possibility before exploring it
    sp-other-term: [
        pos: (stack/rule/enter 'sp-other-term pos)
        sp-left-parenthesis
        any [ sp-unary sp-right-parenthesis sp-left-parenthesis ]
        sp-value sp-right-parenthesis
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; Add a possible location for a left parenthesis (spacer-l)
    ; The location is added to the stack and has the following format :
    ; [ t(type): spacer-l l(evel): <level> p(osition): <pos> a(active): false ]
    ; <level> the current nested level of parenthesis : 1 when no parenthesis, if sub-expression,
    ;         3 if inside a sub-expression, etc.
    ; <pos> position in the input serie, that is at the left of a value or at the left of a sub-expression
    sp-left-parenthesis: [
        pos: (stack/rule/enter 'sp-left-parenthesis pos)
        ( 
            spacer: compose [ 
                t: spacer-l l: (level) p: (index? pos) a: (false)
            ]
            stack/push spacer
        )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; Similarly add a possible location for a right parenthesis
    ; [ t(type): spacer-r l(evel): <level> p(osition): <pos> a(ctive): false ]
    sp-right-parenthesis: [
        pos: (stack/rule/enter 'sp-right-parenthesis pos)
        ( 
            spacer: compose [ 
                t: spacer-r l: (level) p: (index? pos) a: (false)
            ]
            stack/push spacer
        )
        any sp-spacer
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; Spacer locations entered by the user
    ; [ t(type): <type> l(evel): <level> p(osition): <pos> a(active): false o(ffset): <offset> ]
    ; <type> spacer-etss, spacer-efss, spacer-stes, spacer-sfes
    ; <offset> the length of the spacer
    ; <level> see above
    ; <pos> position in the input serie that is at the left of the spacer
    sp-spacer: [
        pos: (stack/rule/enter 'sp-spacer pos)
        into [
            'spacer
            skip skip ; positions ignored
            copy type [ 'ets-spacer | 'efs-spacer | 'ste-spacer | 'sfe-spacer ]
            copy nb integer! ; repetition
        ]
        (
            spacer: compose [ 
                t: (to-word type/1) l: (level) p: (index? pos) a: (false) o: (nb/1)
            ] 
            stack/push spacer
        )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    sp-value: [ sp-elem | sp-sub-expr | sp-absolute? ]
    sp-elem: [ into [ [ 'value | 'constant | 'var ] thru end ] ]

    sp-sub-expr: [
        pos: (stack/rule/enter 'sp-sub-expr pos)
        into [ 'paren skip skip 'paren-l thru end ]
        [
            (level: level + 1) ; increment parenthesis level
            sp-expr
            into [ 'paren skip skip 'paren-r thru end ]
            (level: level - 1)
            |
            (level: level - 1) ; make sure to reverse parenthesis level even in case of failure
            fail
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

    ; In case absolute | is used in an input string, it is ambiguous as it corresponds
    ; both to a unary operation and to a sub-expression. This rule keeps tracks of 
    ; these situations. When modifying the token stream, the corresponding tokens are 
    ; updated with paren-l paren-r markers, and a unary operator is added just before
    ; the opening absolute
    sp-absolute?: [
        pos: (stack/rule/enter 'sp-absolute? pos)
        into [ 'paren skip skip 'absolute? thru end ]
        [
            (level: level + 1) ; increment parenthesis level
            (
                abs: compose [ 
                    t: ('absolute-l) l: (level) p: (index? pos)
                ]
                stack/push abs
            )
            sp-expr
            p: into [ 'paren skip skip 'absolute? thru end ]
            (
                abs: compose [
                    t: ('absolute-r) l: (level) p: (index? p)
                ]
                stack/push abs
            )
            (level: level - 1)
            |
            (level: level - 1) ; make sure to reverse parenthesis level even in case of failure
            fail
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

]
;spacer
;]

;------------------------------------------------------------------------
; Syntactic analyser : builds up the expression tree
; This is where the list of tokens is turned into the target mathematical
; expression encoded as a tree (see recalculator/tree).
; The mechanism is similar as with the lexer, or spacer. A buffer is
; parsed against a set of rules that produce the desired output.
; Here the buffer is the list of tokens (same as the spacer), that 
; was produced as output of the lexer. And the output is the 
; node that is the root of the tree representing the parsed expression.
;----------------------------------------------------------------------
;comment [
syntaxer: context [

    debug: false

    type: 'syntaxer

    stack: none

    ;; Runs
    run: function [
        "Performs the expression analysis"
        ex [object!] "The expression holding the source tokens to process"
        return: [object!] ; expression after modifying /status /tokens /discarded /node
    ][
        source: ex/source
        tokens: ex/tokens
        status: failed: node: none

        ; creates the stack if need be
        if none? self/stack [ self/stack: recalculator/stack/clone ]
        stack/init

        ; check tokens available
        either empty? tokens [
            if debug [ print [ "Syntaxer - no token to parse" ] ]
            status: true
        ][

            ; parse run
            if debug [ print "Syntaxer runs..." ]
            self/lst: none ; make sure last token marker is reset
            status: parse tokens root

            ; if not entirely parsed, keeps failed key entry and clear all failed tokens
            if all [ not status lst not empty? lst ] [
                failed: at source lst/1/2
                clear lst
            ]

            if debug [
                print "The stack after parsing:"
                stack/myprobe
            ]

            ; node is either none or stands at the top of the stack
            node: stack/pop
            if debug and ( not stack/is-empty ) [
                ; should never happen
                print "Stack has extra nodes..."
                stack/myprobe
                status: false
            ]
        ]

        ex/status: status
        ex/node: node
        if failed [ ex/failed: failed ]

        if debug [
            print "Syntaxer - results"
            print ["status:" ex/status]
            print ["source:" mold ex/source]
            print ["failed:" mold ex/failed]
            print ["tokens:" mold ex/tokens]
            print ["node:" either not ex/node [ "none" ] [ tree/mymold ex/node ] ]
        ]

        return ex
    ]

    ;;
    ;; Parsing rules for syntactic analysis - validates the expression and builds up an expression tree
    ;; the rules are similar as those used by the spacer, though more detailed
    ;;

    ; Localize shared rules within this context as paths are not authorized within parse rules
    ; for the sake of performances
    op-binary-add: lexer/op-binary-add
    op-binary-mult: lexer/op-binary-mult
    op-binary-power: lexer/op-binary-power
    op-unary: lexer/op-unary

    ; Words used by the rules (make sure they are local to this context and do not spill out 
    ; anywhere else
    s: x: y: op: none

    ; Last parsed token
    lst: none

    root: [
        (stack/init) 
        lst: additions lst:
    ]
    additions: [
        s: (stack/rule/enter 'additions s)
        multiplications
        any [
            additions-rec
            ; left associativity, meaning the operands are collected as soon as possible from left to right
            ; 3+4+5 translates into ((3+4)+5)
            ; this rule collects the values in the stack and combine them as soon as pos to create the 
            ; corresponding binary node. Then it pushes the result back in the stack
            ( y: stack/pop op: stack/pop x: stack/pop stack/push tree/create/binary op x y )
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    ; rules are split between an initial rule - here additions, and subsequent rule that are optionals.
    ; doing so the last rule can fail, and be backtracked, while keeping the initial rule if any.
    additions-rec: [
        s: (stack/rule/enter 'additions-rec s)
        ; here, the value of the addition operation detected by op-binary-add is pushed in the stack (s/1/4)
        ; for later use in the rule additions just before.
        ; note that s that is used as a marker at the beggining of the rule is also use to collect the value
        ; of the binary operator (s/1/4). Be aware that s is shared by all the rules that modify the stack.
        ; for instance here, s gets irrelevant after multiplications has completed.
        ; parse is not doing anything to restore the context of rule. Hence the need to do that job oneself.
        ; which is a bit silly, if you ask me.
        ; therefore, rules are split in two parts, whatever can be collected (here a value to be
        ; stacked), and then whatever is needed to proceed further (here gets down to the multiplications rule)
        ; if both are successfull, you can validate the stack, otherwise you just rollback.
        into [ 'binary skip skip op-binary-add ] ( stack/push s/1/4 )
        multiplications
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    multiplications: [
        s: (stack/rule/enter 'multiplications s)
        implicit-multiplications
        any [
            multiplications-rec
            ; left associativity
            ( y: stack/pop op: stack/pop x: stack/pop stack/push tree/create/binary op x y )
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    multiplications-rec: [
        s: (stack/rule/enter 'multiplications-rec s)
        into [ 'binary skip skip op-binary-mult ] ( stack/push s/1/4 )
        implicit-multiplications
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    ; an implicit multiplications is added that allows joining two 
    ; values together - for instance 3(4+10) translates into 3 x (4+10) that has 
    ; a higher precedence over the multiplication operator but lower compared 
    ; with the power ( 3^2(3+4) translates into (3^2)(3+4))  
    implicit-multiplications: [
        s: (stack/rule/enter 'implicit-multiplications s)
        powers
        any [
            implicit-multiplications-rec
            ; left associativity
            ( y: stack/pop op: stack/pop x: stack/pop stack/push tree/create/binary op x y )
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    implicit-multiplications-rec: [
        s: (stack/rule/enter 'implicit-multiplications-rec s)
        (stack/push 'implicit-multiply) ; implicit multiplication detected
        powers
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    powers: [
        s: (stack/rule/enter 'powers s)
        unaries
        any [ 
            powers-rec
        ]
        (
            ; right associativity - meaning operands are treated from right to left
            ; in practice, all operands and operators must be stacked prior to build the 
            ; corresponding nodes
            y: stack/pop
            while [ stack/top-1 <> 'sep ] [
                op: stack/pop
                x: stack/pop
                y: tree/create/binary op x y
            ]
            stack/push y
        )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    powers-rec: [
        s: (stack/rule/enter 'mult-part-rec s)
        into [ 'binary skip skip op-binary-power ] ( stack/push s/1/4 )
        unaries
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    ; unary operator can be infix or postfix - both are accepted
    ; infix : like √ or any-function
    ; postfix : like ² or when entered through the display
    ; you can have multiple unary operators chained together
    ; henceforth sine√2 and 2√sin result in the same expression sine ( √ ( 2 ) )
    unaries: [
        s: (stack/rule/enter 'unaries s)
        any [
            ; infix unary operators
            op: into [ 'unary thru end ]
            ( stack/push op/1/4 )
        ]
        value
        (
            ; handle infix operators
            x: stack/pop
            while [ stack/top-1 <> 'sep ] [
                op: stack/pop
                x: tree/create/unary op x
            ]
            stack/push x
        )
        any [
            ; postfix unary operators
            op: into [ 'unary thru end ]
            ( x: stack/pop stack/push tree/create/unary op/1/4 x )
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    value: [
        s: (stack/rule/enter 'value s)
        [ 
            val | 
            cst |
            var |
            sub-expr
        ]        
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    sub-expr: [
        s: (stack/rule/enter 'sub-expr s)
        [
            into [ 'paren skip skip 'paren-l]
            additions
            into [ 'paren skip skip 'paren-r]
            ( x: stack/pop stack/push tree/create/unary 'subexp x )
        ]
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    val: [
        s: (stack/rule/enter 'val s)
        into [ 'value thru end ] 
        ( stack/push tree/create/with 'value s/1/4 )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    cst: [
        s: (stack/rule/enter 'cst s)
        into [ 'constant thru end ]
        ( stack/push tree/create s/1/4 )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]
    var: [
        s: (stack/rule/enter 'var s)
        into [ 'var thru end ] 
        ( stack/push tree/create/with 'var s/1/4 )
        (stack/rule/keep) | (stack/rule/fail) fail
    ]

]
;syntaxer
;]

;--------------------------------------------------------------------------------
; model object : a context for holding and manipulating mathematical expressions
;--------------------------------------------------------------------------------
;comment [
model: make model-core [ ; extends model

    debug: false

    expr: make model-core/expr [

        krnr: none

        ; computed value or none
        val: none

        ; transient, used for detecting circular references
        visited?: false

        ; stack state
        ; true - expression is stacked
        ; false - expression is unstacked (either created or discarded)
        stacked?: false

        ; computation state
        ; true - expression is computed
        ; false - expression is not computable
        ; none - computation state is unknown
        computed?: none

        ; functions referring to the outer context and passing self as argument
        equals: function [o [any-type!] return: [logic!]][ expr-equals self o ]
        clone: function [return: [object!]] [ expr-clone self ]
        modify: function [e [object!] return: [object!]] [ expr-modify self e ]
        add-keys: function [keys [any-word! char! block! string!]][ expr-add-keys self keys ]
        remove-keys: function [nb [integer!]][ expr-remove-keys self nb ]
        remove-all-keys: function [][expr-remove-keys self (length? source)]
        compute: function [/force return: [logic!]] [ either force [ expr-compute/force self ] [ expr-compute self ] ]
        value: function [return: [number!]] [ expr-value self ]
        discard-tokens: function [token [block!]] [ expr-discard-tokens self token ]
        clear: function [return: [object!]] [ expr-clear self ]
        clear-failed: function [return: [object!]] [ expr-clear-failed self]
        probe: function [] [ expr-probe self ]
        line-number: function [ return: [integer!]][ expr-line-number self ]

        ; string for the presenter
        value-as-string: function [return: [string!]] [ expr-value-as-string self ]

        ; debug strings
        mold: function [return: [string!] ] [ expr-mold self ]
        as-string: function [return: [string!]] [ expr-source-as-string self ]
        debug-string: function [return: [string!]] [ expr-debug-string self ]

    ]

    ;----------------------------------------------------------------------------
    ; Expr functions
    ;----------------------------------------------------------------------------

    ; create - a new void expression
    expr-new: function [
        "Creates a new expression"
        buffer [block! string!]
        return: [object!]
        /compute
    ][
        o: make expr [] ; an model/expr object 
        o/source: copy buffer ; make sure its mine !

        ; compute immediately
        if compute [ expr-compute o ]

        o
    ]

    ; check for equality
    expr-equals: function [
        ex [object!]
        o [any-type!]
        return: [logic!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        all [
            object! == (type? o)
            (reflect o 'class) == (reflect ex 'class) ; looks the notion of classes exist (same spec.)
            ex/source == o/source
            ex/failed == o/failed
            ex/tokens == o/tokens
            ex/node == o/node
            ex/val == o/val
            ex/computed? == o/computed?
            ; visited and stacked are transient and irrelevant for comparaison
        ]
    ]

    ; clone an expression, copying the source buffer and all intermediate 
    ; computations
    expr-clone: function [
        ex [object!]
        return: [object!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        o: make expr []
        o/source: either none? ex/source [ none ][ copy ex/source ]
        ; @ZWT alternatively - only clone source and leave pre-computed the rest
        o/failed: either none? ex/failed [ none ][ at o/source index? ex/failed ]
        o/tokens: copy/deep ex/tokens ; in case, though not likely to be impacted
        o/node: ex/node ; no copy - node tree is a value, except for references (@ZWT verify ok)
        o/val: ex/val
        o/computed?: ex/computed?
        o/visited?: false
        o/stacked?: false
        o
    ]

    ; modify an expression with the given source
    expr-modify: function [
        ex [object!]
        o [object!]
        return: [object!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        assert ( in o 'krnr ) "Expects an expr object"
        if same? ex o [ return ex ]
        ex/source: either none? o/source [ none ][ copy o/source ]
        ex/failed: either none? o/failed [ none ][ at ex/source index? o/failed ]
        ex/tokens: copy/deep o/tokens ; not used but tokens could be updated
        ex/node: o/node
        ex/val: o/val
        ex/computed?: o/computed?
        ; ex/visited? transient - not to modify
        ; ex/stacked? should not be changed
        ex
    ]

    ; debug string for expr 
    expr-probe: function [
        ex [object!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        print expr-mold ex
    ]

    ; full debug string for expr
    expr-mold: function [
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        mold compose [
            source: (ex/source)
            failed: (ex/failed)
            tokens: (ex/tokens)
            node: (either none? ex/node [none][tree/mymold ex/node])
            value: (ex/val)
            computed?: (ex/computed?)
            stacked?: (ex/stacked?)
            visited?: (ex/visited?)
        ]
    ]

    ; Clear an expression, resetting all values to void or none
    expr-clear: function [
        ex [object!]
        return: [object!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        clear ex/source
        ex/failed: none
        clear ex/tokens
        ex/node: none
        ex/val: none
        ex/computed?: none
        ex
    ]

    ; Clear failed key entries
    expr-clear-failed: function [
        ex [object!]
        return: [object!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        unless none? ex/failed [
            clear ex/failed
            ex/failed: none
        ]
        ex
    ]

    ; Remove last entered keys
    expr-remove-keys: function [
        ex [object!]
        nb [integer!]
        return: [object!]
    ][  
        assert ( in ex 'krnr ) "Expects an expr object"
        ; nothing to remove
        if nb <= 0 [
            return ex
        ]
        ; reset ex/computed? if valid inputs
        nb-failed: either none? ex/failed [ 0 ] [ length? ex/failed ]
        if nb > nb-failed [
            ex/computed?: none
        ]
        ; clear source
        case [
            nb >= length? ex/source [ clear ex/source ]
            true [ clear at ex/source ( (length? ex/source) - nb + 1 ) ]
        ]
        ; adjust failed keys to none
        if all [
            not none? ex/failed
            ex/failed >= (tail ex/source)
        ][
            ex/failed: none
        ]
        ex
    ]

    ; Add keys, one or several
    expr-add-keys: function [
        ex [object!]
        keys [any-word! char! block! string!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        if any-word? keys [
            keys: to-lit-word keys
        ]
        append ex/source keys
        ex/computed?: none
        ex
    ]

    ; Returns the value of an expression
    expr-value: function [
        ex [object!]
        return: [number!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        if none? ex/computed? [
            if debug [
                print ["Value accessed without prior recomputation for" ex/as-string]
            ]
            ; commented out to avoid backward reference
            ;expr-compute ex
            ;either ex/computed? [
            ;    return ex/val
            ;][
            ;    return none
            ;]
            return none
        ]
        ex/val
    ]

    ; Returns the value as a string to be displayed
    expr-value-as-string: function [
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        v: expr-value ex 
        either none? v [ "" ][ funcs/form v ]
    ]

    ; Debugt string
    expr-debug-string: function [
        "Debug string"
        ex [object!]
        return: [string!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        ; display node if present, display failed source and value
        ; if not, display source
        res: make string! 20
        case [
            ex/computed? [
                append res expr-node-as-string ex
                if ex/failed [
                    append res " [ "
                    append res expr-failed-as-string ex
                    append res " ]"
                ]
                append res " = "
                append res expr-value-as-string ex
            ]
            all [ ex/source not empty? ex/source ][
                append res "[ "
                append res expr-source-as-string ex
                append res " ]"
            ]
            true []
        ]
        res
    ]

    ;
    ; Stack of expressions
    ;
    exprs-stack: copy [] ; the container of expressions

    ; get an expression by line number
    exprs-get: function [ i [integer!] return: [object!] ][
        pick exprs-stack i
    ]

    ;
    ; computation - rely on expr and exprs-stack because of variables
    ;

    ; parse the source buffer using the pipe of lexer, spacer et syntaxer
    _parse-expression: function [
        ex [object!] "The expression to parse"
        return: [object! none!] ; built node or none
    ][
        ; reset intermediate values
        ex/computed?: none
        ex/tokens: copy []
        ex/failed: none
        ex/node: none

        ; lexical analysis
        lexer/run ex

        ; spacer handling
        spacer/run ex

        ; syntaxer
        syntaxer/run ex

        return ex/node

    ]

    ; retrieve the target expression of a given variable
    ; if the matching has already been made check whether the corresponding expression is staked
    ; if not try and retrieve the current expression in the stack at the variable value
    _expression-from-variable: function [ 
        v [block!] "Variable node"
        return: [object!] ; target expression or none
    ][
        e: v/extra
        either none? e [
            ; not matched, search and retrieve from the stack
            e: exprs-get v/value
            either none? e [
                if debug [
                    print ["Found var:" tree/as-string v "- no expression found"]
                ]
            ][
                ; make the match for this variable permanent
                v/extra: e
            ]
        ][
            ; already matched, but is it still stacked ?
            either not e/stacked? [
                if debug [
                    print ["Found var:" tree/as-string v "- expression not stacked:" e/as-string]
                ]
                v/value: 0 ; to be displayed as ?
                e: none
            ][
                ; matched and stacked, make sure the expression line number is correct
                nb: e/line-number
                if v/value <> nb [
                    v/value: nb
                ]
            ]
        ]
        e
    ]

    ; Recompute an expression recursively
    ; 1- verify the sub-expressions referenced,
    ; 2- compute the expression
    ; only recompute if necessary ( not computed yet or a reference was recomputed )
    _expr-compute-rec: function [
        ex [object!]
        force [logic!]
        return: [word!] ; return computed, recomputed or failed
    ][
        if debug [
            print [ "About to recompute" ex/as-string ]
        ]
        ; check for possible cycles during the traversal
        ; any new expression that is not already resolved is marked so, 
        ; and if encountered again that suggests a circular reference
        if ex/visited? [
            if debug [
                print [ "Expression already visited !" ]
            ]
            return 'failed
        ]
        ex/visited?: true
        res: none
        set/any 'res try
        [

            ; parse the expression and recreate the expression tree if need be
            if any [ force none? ex/computed? ] [
                _parse-expression ex
            ]

            node: ex/node
            either none? node [
                ; failed if no node (parsing failed)
                res: 'failed 
            ][
                ; check external references if any
                vars: tree/search-variables node 'var
                foreach v vars [
                    ; retrieve the target expression
                    e: _expression-from-variable v
                    if none? e [
                        res: 'failed
                        break
                    ]
                    ; recursive recomputation if needed
                    if debug [
                        print ["Found var:" tree/as-string v "- recompute expr:" e/as-string]
                    ]
                    r: _expr-compute-rec e force
                    case [
                        r == 'failed [
                            res: 'failed
                            break
                        ]
                        r == 'recomputed [
                            res: 'recomputed
                        ]
                    ]
                ]
            ]
            ; Compute / recompute the current expression
            ; do it if a sub-expression was recomputed, or if 
            ; the current expression needs to recomputed
            case [
                res == 'failed [
                    ex/val: none
                    ex/computed?: false
                    res: 'failed
                ]
                ; recompute the node tree if recomputation is 
                ; required
                any [
                    res == 'recomputed
                    none? ex/computed?
                ][
                    ex/val: tree/compute node
                    ex/computed?: true
                    res: 'recomputed
                ]
                true [
                    ex/computed?: true
                    res: 'computed
                ]
            ]
        ]

        ; reverts visited? flag
        ex/visited?: false
        if all [ value? 'res error? res ] [
            if debug [ 
                print [ "Error encountered" mold res ]
            ]
            res: 'failed
        ]
        if debug [
            print [ "Computation of" ex/as-string "- res:" res "- val:" ex/val "- computed?:" ex/computed? ]
        ]
        res
    ]

    ; Compute an expression
    expr-compute: function [
        "Compute an expression : running the lexical and syntactic analysis and building up the expression tree"
        ex [object!]
        /force "Force the recomputation, otherwise only recompute failed or missing values"
        return: [logic!] ; true if a value was computed successfully
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        ; load the expression, and compute it recursively
        res: _expr-compute-rec ex force
        res <> 'failed
    ]

    ; Line number
    expr-line-number: function [
        ex [object!]
        return: [integer!]
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        exs: exprs-stack
        res: forall exs [ 
            if expr-equals exs/1 ex [
                break/return index? exs
            ]
        ]
        either res [ res ] [ 0 ]
    ]

    ;
    ; Exprs - stack of expressions and the vocabulary to manipulate them
    ;

    ; debug string
    exprs-mold: function [][
        res: make string! 100
        i: 0
        foreach e exprs-stack [
            i: i + 1
            append res i
            append res " "
            append res expr-mold e
        ]
    ]

    ; debug output
    exprs-probe: function [][
        print exprs-mold
    ]

    ; debug string
    exprs-debug-string: function [][
        res: make string! 100
        i: 0
        foreach e exprs-stack [
            i: i + 1
            append res i
            append res ": ["
            append res expr-debug-string e
            append res "]^/"
        ]
        if i > 0 [
            take/last res
        ]
        res
    ]

    ; returns the number of expressions
    exprs-nb: function [ return: [integer!] ][
        length? exprs-stack
    ]

    ; get a shallow copy of all expressions
    exprs-gets: function [][
        copy exprs-stack
    ]

    ; recompute all expressions currently in the stack
    exprs-recompute: function [
        /force
    ][
        if empty? exprs-stack [ exit ]
        ; force the recomputation by setting computed? flag to none
        foreach e exprs-stack [
            if any [ 
                force
                not e/computed?
            ][
                e/computed?: none 
            ]
        ]
        ; resolve each expression recursively
        foreach e exprs-stack [
            expr-compute e
        ]
    ]

    ; returns all variable nodes along with the expressions that use them
    _exprs-variables: function [ 
        return: [block!] ; a block that alternates node and expression (var expr)
    ][
        res: copy []
        foreach expr exprs-stack [
            if expr/node [
                vars: tree/search-variables expr/node 'var
                foreach v vars [
                    append res reduce [v expr]
                ]
            ]
        ]
        res
    ]

    ; add a new expression
    exprs-add: function [ 
        ex [object!]
        /where i [integer!]
        return: [object!] ; expr
    ][
        assert ( in ex 'krnr ) "Expects an expr object"
        assert ( not ex/stacked? ) "Expr already stacked"
        max: 1 + length? exprs-stack
        i: either where [ i ] [ max ]
        ; silently adjust to boundaries
        if i < 1 [ i: 1 ]
        if i > max [ i: max ]
        ; insert the expression in the stack
        insert/only at exprs-stack i ex
        ex/stacked?: true
        ex/computed?: none ; not mandatory but not harmful either
        ; adjust any variable references if need be
        ; no recomputation needed for these so no need
        ; to change the computed? status
        if i < length? exprs-stack [
            foreach [v e] _exprs-variables [
                if v/value >= i [
                    v/value: v/value + 1
                ]
            ]
        ]
        ; recompute, though could recompute the inserted line only
        exprs-recompute
        ex
    ]

    ; remove an expression, adjust the variables and recompute
    exprs-remove: function [
        i [integer!] 
        return: [ object! ] ; the removed element or none
    ][
        ex: pick exprs-stack i
        if none? ex [
            return none
        ]
        remove at exprs-stack i
        ex/stacked?: false
        ; adjust existing variable values to account for the removed line
        foreach [v e] _exprs-variables [
            case [
                v/value > i [ ; adjust reference if shifted
                    v/value: v/value - 1
                ]
                v/value == i [ ; turn to 0 if referencing the removed node
                    v/value: 0
                    e/computed?: false ; invalid the expression
                ]
            ]
        ]
        ; recompute
        exprs-recompute
        ; returns the removed element
        ex
    ]

    ; modify an expression and recompute
    exprs-modify: function [ 
        i [integer!] 
        sr [object!]
        return: [object!] ; the modify element or none
    ][
        assert ( in sr 'krnr ) "Expects an expr object"
        ex: pick exprs-stack i
        if none? ex [ return none ]
        ex/modify sr
        ex/computed?: none
        ; recompute
        exprs-recompute
        ex
    ]

    ; clear all the expressions
    exprs-clear: function [][
        foreach e exprs-stack [
            e/stacked?: false
        ]
        clear exprs-stack
    ]

    ; restore the stack and recompute
    exprs-restore: function [ exprs [block!] ][
        clear exprs-stack
        append exprs-stack reduce exprs ; reduce as exprs may hold words!
        ; reset the computation status to force recomputation
        foreach e exprs-stack [
            e/stacked?: true
            e/computed?: none
        ]
        ; recompute
        exprs-recompute
    ]

]
;model
;]

;
; Presenter : Interface between the model (recalculator/model) and the view (recalculator/display)
; Mainly it manipulates the model, maintains the state of the recalculator, and offers 
; an interface to the view to implement most of the work. It implements all the actions and is able
; to undo or redo any of them. It has no knowledge of the display however. The display gets notified
; of any change using the reactor mechanism : the display reacts to changes made to certain slots of
; the presenter. The display transfer user inputs, and commands by calling functions of the presenter
; (mainly push-key).
;
;comment [
presenter: reactor [

    debug: false

    ; current angle mode
    angle: 'radian

    ; current expression, mutable (as compared with stacked expressions that are immutables)
    expr: model/expr-new []

    ; formatted string to display
    expr-as-string: ""          ; formatted expression for display
    value-as-string: ""         ; computed value for display
    failed-as-string: ""        ; bad-keys formatted for display

    ; stack of expressions in calculator/model
    ; here only a representation to be displayed
    expr-stack-as-list: copy [] ; expr stack as a text list
    expr-index: 0               ; currently selected expression index or 0 if none

    ; tracking if a line was just pulled into the buffer
    ; call to pull-expr sets the value of pulled-expr-index
    ; any other call (key entries, line selection etc.) unsets this value
    ; if clear buffer is called and expr-index-pulled is set, the corresponding stack entry is cleared
    expr-index-pulled: 0

    ; undo/redo stored in a stack format
    ; next-undo pointing to the next command to undo
    ; next-undo/1 for redoing
    ; next-undo/2 for undoing
    ; tail? next-undo - nothing left to undo
    ; head? next-undo - nothing left to redo
    next-undo: copy []

    ;
    ; Debug helper functions
    ;

    ; helper function for testing - general cleanup
    reset: function [][
        ;self/debug: false
        model/exprs-clear
        self/angle: 'radian
        self/expr: model/expr-new []
        self/expr-as-string: ""
        self/value-as-string: ""
        self/failed-as-string: ""
        self/expr-stack-as-list: copy []
        self/expr-index: 0
        self/next-undo: copy []
    ]

    ; also for debug, and regression testing
    expr-debug-string: function [ return: [string!] ][
        expr/debug-string
    ]

    expr-stack-debug: function [ return: [string!] ][
        res: copy []
        collect/into [
            foreach ex model/exprs-gets [
                keep rejoin [ ex/node-as-string " = " ex/value-as-string ]
            ]
        ] res
        res
    ]

    ;;
    ;; Internals
    ;;

    ; Reacts to key buffer update
    ; once the expression has been computed, the various strings to display are refreshed
    ; the reactor framework takes charge to notify the view to refresh the display
    _on-keys-update: function [][

        ; recompute the expression
        expr/compute

        ; refresh displayed strings
        self/failed-as-string: expr/failed-as-string
        self/expr-as-string: expr/node-as-string
        self/value-as-string: expr/value-as-string

        if debug [
            s: expr-debug-string
            if s == "" [ s: "none" ]
            print [ "Expression updated to " s ]
        ]

        exit

    ]

    ; Reacts to expression stack update
    ; similarly once the stack is modified, the list of values is entirely recreated (no subtlety there)
    ; and the text-list is notified using the reactor mechanism
    _on-expr-stack-update: function [][

        ; joining together var id, expression, value
        s: presenter/key-label 'var
        i: 0
        max: model/exprs-nb
        data: collect [
            foreach ex model/exprs-gets [
                i: i + 1
                keep rejoin [
                    "" ; join as string
                    pad/left rejoin [ "" s i ] 3
                    " : "
                    ex/value-as-string 
                    " = "
                    ex/node-as-string 
                ]
            ]
        ]

        ; this triggers display refresh using reactivity framework
        self/expr-stack-as-list: data

        if debug [
            print [ "Stack updated:" mold expr-stack-as-list ]
        ]

        exit

    ]

    ; Retrieved from reactivity.red
    ; Customised to prevent a bug when objects have circular references (see below @ZWT)
    on-change*: function [word old new][
        if system/reactivity/debug? [
            print [
                "-- on-change event --" lf
                tab "word :" word		lf
                tab "old  :" type? :old	lf
                tab "new  :" type? :new
            ]
        ]
        all [
            not empty? srs: system/reactivity/source
            srs/1 = self
            srs/2 = word
            set-quiet in self word old		;-- force the old value
            exit
        ]
        unless all [block? :old block? :new same? head :old head :new][
            if any [series? :old object? :old][
                ;; @ZWT added to prevent buggy call when updating 'expr
                ;print word
                unless any [ 
                    word == 'expr
                    word == 'exprs-stack
                ][
                    modify old 'owned none
                ]
            ]
            if any [series? :new object? :new][modify new 'owned reduce [self word]]
        ]
        system/reactivity/check/only self word
    ]

    ;;
    ;; Interface for the display
    ;;

    ; Returns key label corresponding to a key symbol
    key-label: function [
        key [word!]
        return: [string!]
    ][
        key-entry: select keys key
        return either block? key-entry [key-entry/3]["?"]
    ]

    ;
    ; Commands to change the angle mode
    ; those could be left in the display.
    ; having them here is just handy as they are treated like any other keys.
    ;
    ; switch angle mode to degree
    degree: function [][
        self/angle: 'degree
    ]
    ; switch angle mode to radiant
    radian: function [][
        self/angle: 'radian
    ]
    ; switch angle mode to gradient
    gradient: function [][
        self/angle: 'gradient
    ]

    ; Push a key or a command
    ; This is the main entry point for the display all entered keys are processed here
    ; either triggering a dedicated control command or pushing a key value in the buffer
    push-key: function [
        key [word!]
        return: [logic!]
    ][
        k: select keys key
        if not block? k [
            if debug [
                print [ "Unknown key " key ]
            ]
            return false
        ]
        ; transfer control keys
        if k/2 == 'control [
            cmd: in self k/1
            either not none? cmd [
                return do cmd
            ][
                if debug [
                    print [ "Unknown command for key " key ]
                ]
            ]
        ]
        ; regular key to push
        key-entry to-lit-word key
    ]

    ; Select an expression in the stack
    ; this is notified in return to the display
    sel-expr: function [
        index [integer!]
        return: [integer!] ; effective selection
    ][
        set-quiet in self 'expr-index-pulled 0
        if any [ index == 0 index > model/exprs-nb ] [
            index: 0
        ]
        self/expr-index: index
        expr-index
    ]

    ;;
    ;; Actions keys
    ;;
    ;; Those actions trigger the do/undo mechanism. A command is not performed
    ;; directly but stored in the undo/redo buffer and performed.
    ;; In consequence redo does exactly the same as do.
    ;; And undo attempts to reverse prior actions.
    ;;

    ; Add a key (or several - though not used) to the current expression
    key-entry: function [
        keys [any-word! block!] "A key or a list of keys"
        return: [logic!]
    ][
        either (type? keys) == #[block!] [
            nb-keys: length? keys
            keys: copy keys
        ][
            keys: to-lit-word keys ; make sure lit-word
            nb-keys: 1
        ]
        cmd: compose/deep/only [
            name: 'key-entry
            level: 'buffer
            cmd-do: [ expr/add-keys ( keys ) _on-keys-update ]
            cmd-undo: [ expr/remove-keys ( nb-keys ) _on-keys-update ]
        ]
        dodo cmd
    ]

    ; Back-space : remove last entered key
    back-space: function [
        return: [logic!]
    ][
        if expr/empty? [; nothing to back-space
            return false
        ]
        cmd: compose/deep/only [
            name: 'back-space
            level: 'buffer
            cmd-do: [ expr/remove-keys 1 _on-keys-update ]
            cmd-undo: [ expr/add-keys ( expr/last-key ) _on-keys-update ]
        ]
        dodo cmd
    ]

    ; Clear-expr : clear the current expression in the buffer and possibly also the stack expression
    clear-expr: function [
        return: [logic!]
    ][
        if expr/empty? [ ; no character to clear
            return false
        ]
        ; check if last pulled
        either expr-index-pulled <> 0 [
            if debug [
                print ["Last pulled expression set:" expr-index-pulled]
            ]
            ; clear the buffer and removes the line
            cmd-do: compose [ 
                expr/remove-all-keys 
                model/exprs-remove ( expr-index-pulled ) self/expr-index: 0
                _on-expr-stack-update _on-keys-update
            ]
            cmd-undo: compose/only [
                expr/add-keys ( copy expr/keys )
                model/exprs-add/where ( model/exprs-get expr-index-pulled ) ( expr-index-pulled ) self/expr-index: ( expr-index-pulled )
                _on-expr-stack-update _on-keys-update
            ]
        ][ 
            ; just clear the buffer
            cmd-do: [ expr/remove-all-keys _on-keys-update ]
            cmd-undo: compose/only [ expr/add-keys ( copy expr/keys ) _on-keys-update ]
        ]

        cmd: compose/only [
            name: 'clear-expr
            level: ( either expr-index-pulled <> 0 ['stack]['buffer] )
            cmd-do: ( cmd-do )
            cmd-undo: ( cmd-undo )
        ]
        dodo cmd
    ]

    ; clear-all key : clear all expressions
    clear-all: function [
        return: [logic!]
    ][
        if all [ ; nothing to clear
            model/exprs-nb == 0
            expr/empty?
        ][
            return false
        ]
        cmd: compose/deep/only [
            name: 'clear-all
            level: 'stack
            cmd-do: [ model/exprs-clear self/expr-index: 0 expr/remove-all-keys _on-expr-stack-update _on-keys-update ]
            cmd-undo: [ model/exprs-restore ( copy model/exprs-gets ) self/expr-index: ( expr-index ) expr/add-keys ( copy expr/keys ) _on-expr-stack-update _on-keys-update ]
        ]
        dodo cmd
    ]

    ; enter key : add or update the stack with the current expression, possibly void
    ; if the current expression has failed keys, the failed keys are kept in the buffer
    ; if an expression is selected in the stack (expr-index <> 0), this expression 
    ; is modified (replaced actually), otherwise a new expression is added at the bottom
    ; of the stack
    enter: function [
        return: [logic!]
    ][
        ; nothing to enter if the current expression is not valid
        ; or both the selected expression and current expression are equals
        ; prevents generating unecessary commands that don't change anything
        c: model/exprs-get expr-index
        if any [
            not expr/valid?
            all [ c expr/equals c ]
        ][
            if debug [
                print "Nothing to enter."
                print [ 
                    "expr valid?" expr/valid?
                    "selected" expr-index
                    "equals?" expr/equals c
                ]
            ]
            return false
        ]

        ; forget whatever was previously undone
        ; this is done by default when doing the command (see dodo), 
        ; but here the handling of the failed keys requires doing it now
        ; (because failed keys will be undone and redone)
        forget-undones

        ; if ongoing failed keys, roll them back temporarily
        s: next-undo
        until [
            not all [
                expr/failed?
                undo
            ]
        ]

        if debug [
            if s <> next-undo [
                print ["Keep undos from " (index? s) " to " ((index? next-undo) - 1) ]
            ]
        ]

        ; the buffer should contain the expression that needs being saved
        saved-expr: expr/clone

        ; get rid of all previous buffer commands that served for building the current expression
        ; consequently when undoing this command, the corresponding buffer entries will not be refreshed
        ; only the buffer will be restored
        s: next-undo
        until [
            any [ 
                tail? next-undo
                next-undo/1/level <> 'buffer
                not undo
            ]
        ]
        if s <> next-undo [
            if debug [
                print [ "Remove undos from" index? s "to" (( index? next-undo) - 1) ]
            ]
            remove/part s next-undo
            self/next-undo: s
        ]

        ; enter commands is split in two separate commands :
        ; 1- a command that fills the character buffer (1.1) and updates the stack (1.2)
        ; 2- an extra command (2) that clears the character buffer and leaves void for the next entry to come
        ;
        ; 1.1 - key buffer
        cmd-do: compose/only [ expr/remove-all-keys expr/add-keys ( copy saved-expr/keys ) ]
        cmd-undo: compose/only [ expr/remove-all-keys expr/add-keys ( copy expr/keys ) ]

        ; 1.2 - stack
        modified?: false
        either any [
            expr-index == 0
            expr-index > model/exprs-nb
        ][
            ; newly added expression
            n: model/exprs-nb + 1
            append cmd-do compose [ model/exprs-add/where ( saved-expr ) ( n ) self/expr-index: ( n ) ]
            append cmd-undo compose [ model/exprs-remove ( n ) self/expr-index: 0 ]
        ][
            ; modified existing expression
            modified?: true
            target-saved-expr: model/expr-clone model/exprs-get expr-index
            append cmd-do compose [ model/exprs-modify ( expr-index ) ( saved-expr ) self/expr-index: ( expr-index ) true ] ; final true - for debug
            append cmd-undo compose [ model/exprs-modify ( expr-index ) ( target-saved-expr ) self/expr-index: ( expr-index ) false ] ; final false - for debug
        ]

        ; refreshes the buffer and the list for updating the display
        append cmd-do [ _on-expr-stack-update _on-keys-update ]
        append cmd-undo [ _on-expr-stack-update _on-keys-update ]

        ; builds the corresponding command and inserts it in the undo log and runs it
        cmd: compose/only [
            name: 'enter-1
            level: 'stack
            cmd-do: ( cmd-do )
            cmd-undo: ( cmd-undo )
        ]
        res: dodo/keep cmd

        ; 2- add an extra command for clearing the buffer
        if res [
            cmd: compose/deep/only [
                name: 'enter-2
                level: 'stack
                cmd-do: [ expr/remove-all-keys self/expr-index: ( either modified? [ expr-index ][0] ) _on-keys-update ]
                cmd-undo: [ expr/add-keys ( copy expr/keys ) self/expr-index: ( expr-index ) _on-keys-update ]
            ]
            res: dodo/keep cmd
        ]

        ; now puts back the failed keys that may have been undone temporarily
        if not head? next-undo [
            while [ all [ res not head? next-undo ] ] [
                res: redo
            ]
            if not res [
                if debug [
                    print ["Wish I could undo" ( index? next-undo ) - 1  "commands, but last one failed !" ]
                ]
            ]
        ]
        return res

    ]

    ; Retrieves in the buffer the currently selected expression
    ; if none available, clears the buffer
    pull-expr: function [
        return: [logic!]
    ][
        ; nothing to pull if nothing selected and current expression is empty
        ; or selection and current expression are equal
        selected: model/exprs-get expr-index
        if any [
            all [ (not selected) (expr/empty?) ]
            all [ selected (expr/equals selected) ]
        ][
            ; still reset expr-index-pulled
            set-quiet in self 'expr-index-pulled expr-index
            if debug [
                print "Nothing to pull."
            ]
            return false
        ]
        either none? selected [
            cmd-do: [ expr/remove-all-keys self/expr-index: 0 _on-keys-update ]
            cmd-undo: compose/only [ expr/remove-all-keys expr/add-keys ( copy expr/keys ) self/expr-index: 0 _on-keys-update ]
        ][
            cmd-do: compose/only [ expr/remove-all-keys expr/add-keys ( copy selected/keys ) self/expr-index: ( expr-index ) _on-keys-update ]
            cmd-undo: compose/only [ expr/remove-all-keys expr/add-keys ( copy expr/keys ) self/expr-index: ( expr-index ) _on-keys-update ]
        ]
        cmd: compose/only [
            name: 'pull-expr
            level: 'stack
            cmd-do: ( cmd-do )
            cmd-undo: ( cmd-undo )
        ]
        index: expr-index
        res: dodo cmd

        ; keep track of the last pulled expression (see clear-expr for its use)
        set-quiet in self 'expr-index-pulled index

        return res
    ]

    ;;
    ;; Undos / Redos
    ;;

    ; undo for debug
    undo-debug-string: function [][
        print "Undos..."
        print [ "Current index" index? next-undo ]
        u: head next-undo
        forall u [
            b: compose [ 
                "name:" (u/1/name)
                "level:" (u/1/level)
                "cmd-do:" (mold/flat u/1/cmd-do)
                "cmd-undo:" (mold/flat u/1/cmd-undo)
            ]
            print [ index? u mold b ]
        ]
    ]

    ; if next-undo is not on top, clears passed undones
    forget-undones: function [][
        if not head? next-undo [
            remove/part (head next-undo) next-undo
            self/next-undo: head next-undo
        ]
        exit
    ]

    ; pushes a new undo/redo command and does it
    dodo: function [
        cmd [block!] "Command"
        return: [logic!] ;"Command result"
        /keep "To keep currently undones"
    ][

        ; reset the value of the last expression pulled
        set-quiet in self 'expr-index-pulled 0

        ; forget undones unless they should be preserved (see enter)
        if not keep [
            forget-undones
        ]

        ; appends before current next undo
        insert/only next-undo cmd

        ; forces refresh (this is to ensure the display is refreshed using the reactor mechanism)
        self/next-undo: next-undo

        ; performs the command
        if debug [
            print [ "About to run:" cmd/name ]
            print [ "cmd-do:" mold cmd/cmd-do ]
        ]

        ; most undo/redo commands return nothing, so avoid being caught by an unset value
        ; using set/any in case try returns unset
        set/any 'err try cmd/cmd-do
        res: either all [ value? 'err error? err ][
            if debug [ 
                print [ "Error encountered while running" cmd/name ]
                print mold err
            ]
            false
        ][
            true
        ]

        if debug [
            c: collect [
                u: head next-undo
                forall u [ keep u/1/name ] 
            ]
            print [ "Undos updated:" mold c "current undo:" index? next-undo ]
        ]

        return res

    ]

    ; undo
    undo: function [
        return: [logic!] ; true if undo performed
    ][
        if tail? next-undo [ ; next-undo is tail => no undo left
            if debug [ print ["No undo (undo tail reached)"] ]
            return false
        ]
        if debug [
            print ["Undo:" next-undo/1/name "cmd-undo:" mold next-undo/1/cmd-undo]
        ]
        set/any 'err try next-undo/1/cmd-undo ; most command return nothing, so avoid being caught by an unset value
        res: either all [ value? 'err error? err ][
            if debug [ 
                print [ "Error encountered while undoing" next-undo/1/name ]
                print mold err
            ]
            false
        ][
            true
        ]

        self/next-undo: next next-undo
        return res
    ]

    ; redo last undone
    redo: function [
        return: [logic!] ; true if redo performed
    ][
        if head? next-undo [ ; next-undo is head => no dodo left
            if debug [ print ["Nothing to do left (undo head reachede)"] ]
            return false
        ]
        self/next-undo: back next-undo

        if debug [
            print ["Redo:" next-undo/1/name "cmd-do:" mold next-undo/1/cmd-do]
        ]
        set/any 'err try next-undo/1/cmd-do ; most command return nothing, so avoid being caught by an unset value
        res: either all [ value? 'err error? err ][
            if debug [ 
                print [ "Error encountered while redoing" next-undo/1/name ]
                print mold err
            ]
            false
        ][
            true
        ]

        return res

    ]

]
;presenter
;]

;
; Recalculator display
; the calculator view and a small wrapper around it with locals and helper functions
;
;comment [
display: object [

    ; run the display
    run: function [] [
        view/no-wait window
    ]

    ; localize styles
    expr-list: expr: cmd: key: op: nbr: menu: opt: none

    ; localize hiddgen widgets
    h: a-cmd: a-cmd-clicked: a-op: a-op-clicked: a-nbr: a-nbr-clicked: none

    ; localize widgets
    the-exprs: the-trigo: none

    ; to localize some values used by view actors - should not have to do that
    list: s: nb: i: none


    ; the main stuff - the view layout
    window: layout [

        title "Recalculator"
        space 1x1

        ; hidden, used to recatch focus (i.e. to prevent focusing on a widget, you can just send the focus here)
        h: field 0x0 hidden

        ;
        ; Widget styles
        ;

        ; style for expression list
        style expr-list: text-list 245.245.245 font-size 10 ; could use a different font-name also

        ; style for the mathematical expressions
        style expr: text 372x24 240.240.240 font-size 12 right

        ; style for the command button 
        ; its displayed value is provided by the underlying model expression given
        ; the value in data that is the value of the key
        ; a hack allows modifying the font size so as give a feel of liveliness to the button
        ; when clicked
        style cmd: button 72x38 font-size 12
            on-create [ face/text: presenter/key-label face/data ]
            on-down [ face/font: a-cmd-clicked/font ]
            on-up [ face/font: a-cmd/font ]
        a-cmd: cmd 0x0 hidden "" data 'a-cmd 
        a-cmd-clicked: cmd 0x0 hidden "" data 'a-cmd-clicked font-size 14

        ; default style for key buttons
        ; add the ability to push the key value to the mode
        style key: cmd
            [ 
                presenter/push-key face/data
                return 'done
            ]
        
        ; style for main operators with a bit of boldness
        style op: key font-size 18
            on-down [ face/font: a-op-clicked/font ]
            on-up [ face/font: a-op/font ]
        a-op: op 0x0 hidden "" data 'a-op 
        a-op-clicked: op 0x0 hidden "" data 'a-op-clicked font-size 20
        
        ; style for digits with another boldness
        ; wish I could modify the color as well but looks being impossible 
        ; for the time being
        style nbr: key font-size 14 bold
            on-down [ face/font: a-nbr-clicked/font ]
            on-up [ face/font: a-nbr/font ]
        a-nbr: nbr 0x0 hidden "" data 'a-nbr
        a-nbr-clicked: nbr 0x0 hidden "" data 'a-nbr-clicked font-size 16

        ; style for button menu
        ; this allows displaying a small popup window for displaying a sub-menu of keys
        style menu: button 72x38 font-size 10
            with [ 
                data: [] ; expecting key list
            ]
            on-click [
                pop: copy [
                    space 1x1
                    style menu-opt: button 65x34 font-size 10 [
                        presenter/push-key face/data 
                        unview
                        return 'done
                    ]
                    menu-opt "×" font-size 18 [ unview ]
                ]
                foreach opt face/data [
                    either opt == 'return [ append pop 'return ][
                        append pop compose [ menu-opt ( presenter/key-label opt ) data ( to-lit-word opt ) ]
                    ]
                ]
                view/flags/options pop
                [ 'modal 'popup 'no-title 'no-border 'no-buttons ]
                [ offset: event/window/offset + face/offset + event/offset ]
            ]
        
        ; style for option button (not used currently - but will once RPN is introduced)
        style opt: button 72x38 font-size 10
            with [
                ; expecting key list of options
                data: []
                selected: 0
            ]
            on-create [
                ; select first item on creation, once data is provided
                if 0 <> length? face/data [ 
                    face/selected: 1
                    ; note that using do-actor just means that ie. performing whatever is implemented in the actor handler
                    ; note the actual thing the system widget is doing !
                    do-actor face none 'change
                    do-actor face none 'select
                ]
            ]
            on-click [
                ; rotate selected option
                if 0 == length? face/data [ exit ]
                face/selected: ( remainder face/selected ( length? face/data ) ) + 1 ; instead of pourcent
                do-actor face none 'change
                do-actor face none 'select
            ]
            on-change [
                ; synchronize text - in case of selection
                face/text: case [
                    0 == length? face/data [ "?" ]
                    0 == face/selected [ "?" ]
                    true [ rejoin [ presenter/key-label face/data/(face/selected) "…" ] ]
                ]
            ]

        ;here a possible usage for the option button
        ;rpn: opt data [ regular rpn ]
        ;    on-select [
                ; change the model on select
        ;        presenter/mode: face/data/(face/selected)
        ;]

        ;
        ; displayed widgets from top to bottom, and left to right (bottom flow)
        ;

        return ; to make sure hidden widgets before don't interfere with visible ones

        ; the list of expressions
        the-exprs: expr-list 373x105
            with [
                extra: compose [ 
                    nb-voids: 0 ; nb void line used as a filler to make sure the last line appears at the bottom
                    selected: (none) ; selected value when on-down event triggers (see on-down, on-change, on-dbl-click)
                    picked: (none)  ; picked value when on-down event triggers (see on-down, on-change, on-dbl-click)
                ] 
            ]
            react [
                ; adjust the list of expressions that is displayed
                ; - adds an extra line at the end of the list for unselecting (doesn't work otherwise)
                ; - adds extra lines at the begining to make sure the last expression always displays
                ;   at the bottom
                list: copy presenter/expr-stack-as-list
                face/extra/nb-voids: 0
                if (length? list) < 6 [ ; 6 lines if font-size 10, though something more dynamic should be used
                    face/extra/nb-voids: (6 - length? list) ; nb void lines in the list
                    insert/dup list "" face/extra/nb-voids
                ]
                face/data: list
                ; update selected status
                face/selected: length? list ; make sure last line is always apparent
                face/selected: none
            ]
            react [ ; react to select change in model
                s: presenter/expr-index
                s: either s == 0 [ none ] [ s + face/extra/nb-voids ]
                if face/selected <> s [
                    face/selected: s
                ]
            ]
            on-down [
                ;print ["on-down picked:" event/picked " selected:" face/selected]

                ;
                ; called when mouse is clicked on the widget
                ; event/picked == none (list clicked but not on an existing line)
                ; event/picked == number (a line is clicked)
                ; 
                ; here nothing is done, just note the current selected line and the picked line
                ; make sure also the event propagates
                ;
                ; the actual change takes place later in on-change event (selection) 
                ; and on-dbl-click (double selection)
                ;

                ; note the current status for later
                face/extra/selected: face/selected
                face/extra/picked: event/picked

                ; make sure event propagates (event picked/picked == face/selected - neither
                ; on-select nor on-change after are sent)
                face/selected: either event/picked [ none ] [ length? face/data ]
            ]
            on-select [
                ;print ["on-select picked:" event/picked " selected:" face/selected]
                ; do nothing
            ]
            on-change [
                ;print ["on-change picked:" event/picked " selected:" face/selected]
                ; here forces the face/selected, also notifies the model
                ; possibly undo what the default handling has done
                ; therefore don't care about the current face/selected and event/picked
                ; but only use the ones that were kept when receiving on-down event
                either any [
                    not face/extra/picked ; selection of no line
                    face/extra/picked <= face/extra/nb-voids ; filler line selected
                    face/extra/picked == face/extra/selected ; same line selected
                ][
                    face/selected: none
                    attempt [ presenter/sel-expr 0 ]
                ][
                    face/selected: face/extra/picked
                    attempt [ presenter/sel-expr face/extra/picked - face/extra/nb-voids ]
                ]
            ]
            on-dbl-click [
                ;print ["on-dbl-click picked:" event/picked " selected:" face/selected]
                ; here single click turn out to be a double - click
                ; forces the selection, notifies the model and trigger the pull-expr command
                either any [ 
                    not face/extra/picked
                    face/extra/picked <= face/extra/nb-voids
                ][
                    face/selected: none
                    attempt [ presenter/sel-expr 0 ]
                ][
                    face/selected: face/extra/picked
                    attempt [ presenter/sel-expr face/extra/picked - face/extra/nb-voids ]
                    attempt [ presenter/pull-expr ]
                ]
            ]
        space 1x1
        return

        ; formatted expression : reacts to presenter/expr-as-string
        ; very much stupid otherwise
        expr react [
            face/data: either ( s: presenter/expr-as-string ) == "" [
                s
            ][
                rejoin [ s " =" ]
            ]
        ]
        return

        ; value : idem with presenter/value-as-string
        expr 372x38 font-size 18 bold
            react [ face/data: presenter/value-as-string ]
        return

        ; remaining keys : idem with presenter/failed-as-string
        pad 0x-10
        expr 372x20 font-size 8 
            react [ face/data: presenter/failed-as-string ]
        return

        ; control keys
        key data 'undo ; the styling and the use of data allows a nice and terse description of the view !
            react [ face/enabled?: not tail? presenter/next-undo ] ; turn on/off according to the undo log status
        key data 'redo
            react [ face/enabled?: not head? presenter/next-undo ]
        key data 'clear-all
        key data 'clear-expr
        key data 'back-space
        return

        key data 'E
        key data 'PI
        key data 'pourcent
        key data 'exps
        key data 'var
        return

        ; spacers
        menu "Spacer…" data [ sfe-spacer ste-spacer ]
        key data 'efs-spacer
        key data 'ets-spacer
        key data 'paren-l
        key data 'paren-r
        return

        menu "Other…" data [
            modulo remainder return
            round ceil floor return
            absolute factorial random
        ]
        key data 'negate
        key data 'inverse
        op data 'divide
        op data 'multiply
        return

        menu "Hyper…" data [ return
            sinh cosh tanh return
            sinh-1 cosh-1 tanh-1 return
            csch sech coth return
            csch-1 sech-1 coth-1
        ]
        nbr data 'n7 
        nbr data 'n8 
        nbr data 'n9 
        op data 'subtract
        return

        menu "Power…" data [ return
            power-2 power-3 power return
            square-2 square-3 square
        ]
        nbr data 'n4
        nbr data 'n5
        nbr data 'n6
        op data 'add
        return

        menu "Log/exp…" data [ return
            log-10 log-e log-2 return
            exp-10 exp-e exp-2
        ]
        n1: nbr data 'n1
        nbr data 'n2
        nbr data 'n3
        op data 'enter 72x79         ; if you play with the size...
        return

        pad 0x-41                    ; you need to adjust the following line
        the-trigo: menu "Trigo…" data [] ; see below how it is being filled
        nbr data 'n0 147x38
        key data 'decimal-separator
        return

        do [
            ; whenever presenter/angle changes, change the trigonometric functions are 
            ; adjusted in the corresponding menu
            react [
                switch presenter/angle [
                    radian [
                        the-trigo/text: "Trigo rad…"
                        the-trigo/data: [ degree gradient return
                            sine-r cosine-r tangent-r return 
                            sine-1-r cosine-1-r tangent-1-r return
                            cosecant-r secant-r cotangent-r return
                            cosecant-1-r secant-1-r cotangent-1-r
                        ]
                    ]
                    degree [
                        the-trigo/text: "Trigo deg…"
                        the-trigo/data: [ radian gradient return
                            sine-d cosine-d tangent-d return 
                            sine-1-d cosine-1-d tangent-1-d return
                            cosecant-d secant-d cotangent-d return 
                            cosecant-1-d secant-1-d cotangent-1-d return
                            to-dms to-deg return
                        ]
                    ]
                    gradient [
                        the-trigo/text: "Trigo grad…"
                        the-trigo/data: [ radian degree return
                            sine-g cosine-g tangent-g return
                            sine-1-g cosine-1-g tangent-1-g return
                            cosecant-g secant-g cotangent-g return
                            cosecant-1-g secant-1-g cotangent-1-g 
                        ]
                    ]
                ]
            ]
        ]

    ]
    ;windows

    ;
    ; Temporarily used to convert a keystroke into a key entry to be fed to the model
    ; It covers simple keys (digits, operators, parenthesis and some simple commands), 
    ; however not the ability to enter functions and so on. A new mode is required for
    ; that with an entry field and a dedicated lexical analysis, though it should be straightforward
    ; with whatever is already available.
    ;
    key-map: [
        #"0" 'n0
        #"1" 'n1
        #"2" 'n2
        #"3" 'n3
        #"4" 'n4
        #"5" 'n5
        #"6" 'n6
        #"7" 'n7
        #"8" 'n8
        #"9" 'n9
        #"." 'decimal-separator
        #"," 'decimal-separator
        #"+" 'add
        #"-" 'subtract
        #"/" 'divide
        #"*" 'multiply
        #"^H" 'back-space
        #"^M" 'enter
        #"^Z" 'undo
        #"^Y" 'redo
        home 'clear-all
        end 'clear-expr
        #"(" 'paren-l
        #")" 'paren-r
        #"#" 'var
    ]

    ;
    ; Helper functions that provides the face corresponding to
    ; a certain key-value
    ;
    get-face: function [ 
        key [any-word!] 
        return: [object!] 
    ][
        a: none
        foreach-face window [
            if face/data = key [
                a: face
                break
            ]
        ]
        return a
    ]

    ;;
    ;; Set the window actors with on-key event handler to collect keystrokes from
    ;; the keyboard
    ;;
    do [ ; for the compilation to turn into an evaled block
        window/actors: context [
            on-key: function [face [object!] event [event!]][
                action: select key-map event/key
                if action [
                    f: get-face action 
                    unless none? f [
                        ; triggers the font effect but not the actual pressing of the key !
                        ; to have that you would need red/systeming and interacting directly with
                        ; the os api - sad !
                        do-actor f none 'click 
                    ]
                ]
                if debug [
                    either action [ 
                        print ["Key" event/key "runs" action]
                    ][ 
                        print [ "Unknown mapping for" mold event/key]
                    ]
                ]
                'done ; that is said to be used (though I doubt)
            ]
        ]
    ]

]
;display
;]

; Display and run the recalculator
run: function [] [

    ; new randomisation seed
    random/seed now/time

    ; make sure auto-sync works
    system/view/auto-sync?: yes

    ; reset the presenter - in case already ran
    presenter/reset

    ; run the display
    display/run

]
;run
;]

]
;recalculator
;]

case [
    any [
        not system/console ; compiled version
        system/options/script ; script ran from the command line
    ][
        recalculator/run
        do-events ; start the ui event loop until the window is closed
        'ok
    ]
    value? 'recalculator-test [ ; assume test is under way, let recalculator-test be in charge
        'ok
    ]
    true [ ; in all other cases, assume script evaluation from a console already running
        recalculator/run
        'ok
    ]
]
