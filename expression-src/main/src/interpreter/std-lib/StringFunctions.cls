/**
 * @description Repository of functions that can be used in expressions.
 * @group String
 * @function-repository true
 * @display-icon utility:text
 */
public with sharing class StringFunctions {
    // Cache maps used across all EVAL function instances 
    private static Map<Id, SObject> CACHED_RECORDS = new Map<Id, SObject>();
    private static Map<Id, Long> LAST_QUERY_TIME_BY_RECORD_ID = new Map<Id, Long>();
    private static Map<String, Set<String>> EXPRESSION_FIELD_CACHE = new Map<String, Set<String>>();
    private static Set<String> COMPLETED_QUERIES = new Set<String>();
    
    private static final Map<String, StandardFunction> FUNCTIONS = new Map<String, StandardFunction>{
        'BEGINS' => new StringFunctions.Begins(),
        'CONTAINS' => new StringFunctions.Contains(),
        'LOWER' => new StringFunctions.Lower(),
        'FIND' => new StringFunctions.FindFn(),
        'LEFT' => new StringFunctions.LeftFn(),
        'LEN' => new StringFunctions.LenFn(),
        'LPAD' => new StringFunctions.LPadFn(),
        'RPAD' => new StringFunctions.RPadFn(),
        'REVERSE' => new StringFunctions.ReverseFn(),
        'MID' => new StringFunctions.MidFn(),
        'SUBSTRING' => new StringFunctions.SubstringFn(),
        'RIGHT' => new StringFunctions.RightFn(),
        'BR' => new StringFunctions.BrFn(),
        'HYPERLINK' => new HyperLinkFn(),
        'SUBSTITUTE' => new SubstituteFn(),
        'TEXT' => new TextFn(),
        'TRIM' => new TrimFn(),
        'UPPER' => new UpperFn(),
        'VALUE' => new ValueFn(),
        'SPLIT' => new SplitFn(),
        'INITCAP' => new InitCapFn(),
        'URLENCODE' => new UrlEncodeFn(),
        'LIKE' => new LikeFn(),
        'EVAL' => new EvalFn()
    };

    public class StringFunctionsProvider implements FunctionProvider {
        public Map<String, StandardFunction> getFunctions() {
            return FUNCTIONS;
        }
    }

    /**
     * @description Returns TRUE if the first character(s) in a text field match a given string.
     *
     * Accepts 2 arguments: the text field and the string to match.
     * @function BEGINS
     * @example
     * BEGINS("Hello World", "Hello") // TRUE
     */
    private class Begins extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "BEGINS" function: the argument must evaluate to a string value.'
                );
            }

            Object prefix = evaluate(arguments.get(1));
            if (!(prefix instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "BEGINS" function: the argument must evaluate to a string value.'
                );
            }

            return ((String) text).startsWith((String) prefix);
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }
    }

    /**
     * @description Returns TRUE if a text field contains a given string.
     *
     * Accepts 2 arguments: the text field and the string to match.
     * @function CONTAINS
     * @example
     * CONTAINS("Hello World", "World") // TRUE
     */
    private class Contains extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object firstValue = evaluate(arguments.get(0));
            if (!(firstValue instanceof String) && !(firstValue instanceof List<Object>)) {
                throw new FunctionExecutionException(
                    'Error executing "CONTAINS" function: the argument must evaluate to a string or list value.'
                );
            }

            // When dealing with text
            if (firstValue instanceof String) {
                Object substring = evaluate(arguments.get(1));
                if (!(substring instanceof String)) {
                    throw new FunctionExecutionException(
                        'Error executing "CONTAINS" function: the argument must evaluate to a string value.'
                    );
                }

                return ((String) firstValue).contains((String) substring);
            }

            // When dealing with lists
            Object value = evaluate(arguments.get(1));
            List<Object> castList = (List<Object>) firstValue;
            return castList.contains(value);
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }
    }

    /**
     * @description Converts all letters in the specified text to lowercase.
     *
     * Accepts 1 argument: the text to convert.
     * @function LOWER
     * @example
     * LOWER("Hello World") // "hello world"
     */
    private class Lower extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "LOWER" function: the argument must evaluate to a string value.'
                );
            }

            return ((String) text).toLowerCase();
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Returns the starting position of one text string within another text string. If the text string is not found, FIND
     * returns a value -1.
     *
     * Accepts either 2 or 3 arguments: the text to find, the text to search, and optionally the starting position.
     * @function FIND
     * @example
     * FIND("World", "Hello World") // 7
     * FIND("World", "Hello World", 7) // -1
     */
    private class FindFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object searchText = evaluate(arguments.get(0));
            if (!(searchText instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "FIND" function: the argument must evaluate to a string value.'
                );
            }

            Object text = evaluate(arguments.get(1));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "FIND" function: the argument must evaluate to a string value.'
                );
            }

            // There might be an optional third argument for the starting index, if there isn't one, it defaults to 0.
            Integer startIndex = 0;
            if (arguments.size() > 2) {
                Object startIndexValue = evaluate(arguments.get(2));
                if (!(startIndexValue instanceof Decimal)) {
                    throw new FunctionExecutionException(
                        'Error executing "FIND" function: the argument must evaluate to a number value.'
                    );
                }
                startIndex = ((Decimal) startIndexValue).intValue();
            }

            return ((String) text).indexOf((String) searchText, startIndex);
        }

        public override Arity getArity() {
            return Arity.between(2, 3);
        }
    }

    /**
     * @description Returns the specified number of characters from the beginning of a text string.
     *
     * Accepts 2 arguments: the text to evaluate and the number of characters to return.
     * @function LEFT
     * @example
     * LEFT("Hello World", 5) // "Hello"
     */
    private class LeftFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object textObj = evaluate(arguments.get(0));
            if (!(textObj instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "LEFT" function: the argument must evaluate to a string value.'
                );
            }

            Object length = evaluate(arguments.get(1));
            if (!(length instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing "LEFT" function: the argument must evaluate to a number value.'
                );
            }
            String text = (String) textObj;

            if (text.length() <= (Decimal)length) {
                return text;
            }
            return ((String) text).substring(0, ((Decimal) length).intValue());
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }
    }

    /**
     * @description Returns the number of characters in a text string.
     *
     * Accepts 1 argument: the text to evaluate.
     * @function LEN
     * @example
     * LEN("Hello World") // 11
     */
    private class LenFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "LEN" function: the argument must evaluate to a string value.'
                );
            }

            return ((String) text).length();
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    private virtual class LRPad extends StandardFunction {
        private final String name;

        public LRPad(String name) {
            this.name = name;
        }

        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing ' + name + ' function: the first argument must evaluate to a string value.'
                );
            }

            Object length = evaluate(arguments.get(1));
            if (!(length instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing ' + name + ' function: the second argument must evaluate to a number value.'
                );
            }

            Object padString = ' ';
            if (arguments.size() > 2) {
                padString = evaluate(arguments.get(2));
                if (!(padString instanceof String)) {
                    throw new FunctionExecutionException(
                        'Error executing ' + name + ' function: the third argument must evaluate to a string value.'
                    );
                }
            }

            if (name == 'LPAD') {
                return ((String) padString).repeat(((Decimal) length).intValue() - ((String) text).length()) + (String) text;
            } else {
                return (String) text + ((String) padString).repeat(((Decimal) length).intValue() - ((String) text).length());
            }
        }

        public override Arity getArity() {
            return Arity.between(2, 3);
        }
    }

    /**
     * @description Returns a text value padded to the specified length with the specified set of characters.
     *
     * Accepts 2 or 3 arguments: the text to pad, the length to pad to, and optionally the padding character.
     * If the padding character is not specified, it defaults to a space.
     * @function LPAD
     * @example
     * LPAD("Hello", 10) // "     Hello"
     * LPAD("Hello", 10, "*") // "*****Hello"
     */
    private class LPadFn extends LRPad {
        public LPadFn() {
            super('LPAD');
        }
    }

    /**
     * @description Returns a text value padded to the specified length with the specified set of characters.
     *
     * Accepts 2 or 3 arguments: the text to pad, the length to pad to, and optionally the padding character.
     * If the padding character is not specified, it defaults to a space.
     * @function RPAD
     * @example
     * RPAD("Hello", 10) // "Hello     "
     * RPAD("Hello", 10, "*") // "Hello*****"
     */
    private class RPadFn extends LRPad {
        public RPadFn() {
            super('RPAD');
        }
    }

    /**
     * @description Returns a text value with the order of the characters reversed.
     *
     * Accepts 1 argument: the text to reverse.
     * @function REVERSE
     * @example
     * REVERSE("Hello World") // "dlroW olleH"
     */
    private class ReverseFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object val = evaluate(arguments.get(0));
            // Must evaluate to string or list
            if (!(val instanceof String) && !(val instanceof List<Object>)) {
                throw new FunctionExecutionException(
                    'Error executing "REVERSE" function: the argument must evaluate to a string or list value.'
                );
            }

            if (val instanceof String) {
                return ((String) val).reverse();
            } else {
                List<Object> reversedList = new List<Object>();
                for (Integer i = ((List<Object>) val).size() - 1; i >= 0; i--) {
                    reversedList.add(((List<Object>) val).get(i));
                }
                return reversedList;
            }
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Returns a specified number of characters from a text string starting at the position you specify up
     * to the number of characters you specify.
     *
     * Note that the position is 1-based, not 0-based.
     *
     * Accepts 3 arguments: the text to evaluate, the starting position, and the number of characters to return.
     * @function MID
     * @example
     * MID("Hello World", 7, 5) // "World"
     */
    private class MidFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "MID" function: the first argument must evaluate to a string value.'
                );
            }

            Object start = evaluate(arguments.get(1));
            if (!(start instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing "MID" function: the second argument must evaluate to a number value.'
                );
            }

            Object length = evaluate(arguments.get(2));
            if (!(length instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing "MID" function: the third argument must evaluate to a number value.'
                );
            }

            return ((String) text).substring(((Decimal) start).intValue() - 1, ((Decimal) start).intValue() - 1 + ((Decimal) length).intValue());
        }

        public override Arity getArity() {
            return Arity.exactly(3);
        }
    }

    /**
     * @description Returns a specified number of characters from a text string starting at the position you specify.
     * Optionally, you can specify the number of characters to return.
     *
     * Note that the position is 1-based, not 0-based.
     *
     * Accepts 2 or 3 arguments: the text to evaluate and the starting position. Optionally, the number of characters to.
     * @function SUBSTRING
     * @example
     * SUBSTRING("Hello World", 7) // "World"
     * SUBSTRING("Hello World", 7, 5) // "World"
     */
    private class SubstringFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SUBSTRING" function: the first argument must evaluate to a string value.'
                );
            }

            Object start = evaluate(arguments.get(1));
            if (!(start instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing "SUBSTRING" function: the second argument must evaluate to a number value.'
                );
            }

            // Third argument is optional
            Object length = null;
            if (arguments.size() > 2) {
                length = evaluate(arguments.get(2));
                if (!(length instanceof Decimal)) {
                    throw new FunctionExecutionException(
                        'Error executing "SUBSTRING" function: the third argument must evaluate to a number value.'
                    );
                }
            }

            if (length == null) {
                return ((String) text).substring(((Decimal) start).intValue() - 1);
            } else {
                return ((String) text).substring(((Decimal) start).intValue() - 1, ((Decimal) start).intValue() - 1 + ((Decimal) length).intValue());
            }
        }

        public override Arity getArity() {
            return Arity.between(2, 3);
        }
    }

    /**
     * @description Returns the specified number of characters from the end of a text string.
     *
     * Accepts 2 arguments: the text to evaluate and the number of characters to return.
     *
     * If the second argument is a negative number, it gets treated as a 0
     * @function RIGHT
     * @example
     * RIGHT("Hello World", 5) // "World"
     * RIGHT("Hello World", -5) // ""
     */
    private class RightFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "RIGHT: function: the first argument must evaluate to a string value.'
                );
            }

            Object length = evaluate(arguments.get(1));
            if (!(length instanceof Decimal)) {
                throw new FunctionExecutionException(
                    'Error executing "RIGHT" function: the second argument must evaluate to a number value.'
                );
            }

            // If the number is less than 0, force it to 0
            Integer lengthAsInteger = ((Decimal) length).intValue();
            if (lengthAsInteger < 0) {
                lengthAsInteger = 0;
            }

            return ((String) text).right(lengthAsInteger);
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }
    }

    /**
     * @description Inserts a line break in a string of text.
     *
     * When no arguments are provided, it inserts a line break. When a number is provided, it inserts that number of line
     *
     * ⚠️ Note that the inserted line break depends on the call context based on the
     * [Request Quiddity](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_Quiddity.htm). When called from
     * an Aura/LWC or Visualforce context it will insert a `<br>` tag, otherwise it will insert a newline character.
     * @function BR
     * @example
     * BR() // "<br/>"
     * BR(2) // "<br/><br/>"
     */
    private class BrFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Integer linesToAdd = 1;
            // If an argument was passed, then it must be a number
            if (arguments.size() > 0) {
                Object linesToAddValue = evaluate(arguments.get(0));
                if (!(linesToAddValue instanceof Decimal)) {
                    throw new FunctionExecutionException(
                        'Error executing "BR" function: the argument must evaluate to a number value.'
                    );
                }
                linesToAdd = ((Decimal) linesToAddValue).intValue();
            }

            if (Request.getCurrent().getQuiddity() == Quiddity.AURA || Request.getCurrent().getQuiddity() == Quiddity.VF) {
                return '<br/>'.repeat(linesToAdd);
            }
            return '\n'.repeat(linesToAdd);
        }

        public override Arity getArity() {
            return Arity.between(0, 1);
        }
    }

    /**
     * @description Returns a text string of an HTML anchor tag that displays a hyperlink.
     *
     * Accepts 2 or 3 arguments: the URL and the text to display. Optionally, the third argument is the target
     * of the link.
     *
     * The target should be one of `_blank`, `_parent`, `_self`, or `_top`.
     * @function HYPERLINK
     * @example
     * HYPERLINK("https://www.google.com", "Google") // "<a href="https://www.google.com">Google</a>"
     */
    private class HyperLinkFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // Check that the first argument is a string
            Object url = evaluate(arguments.get(0));
            if (!(url instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "HYPERLINK" function: the first argument must evaluate to a string value.'
                );
            }

            // Check that the second argument is a string
            Object friendlyText = evaluate(arguments.get(1));
            if (!(friendlyText instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "HYPERLINK" function: the second argument must evaluate to a string value.'
                );
            }

            // Check that the third argument is a string (if present)
            Object target = null;
            if (arguments.size() > 2) {
                target = evaluate(arguments.get(2));
                if (!(target instanceof String)) {
                    throw new FunctionExecutionException(
                        'Error executing "HYPERLINK" function: the third argument must evaluate to a string value.'
                    );
                }
            }

            // Create the link
            String link = '<a href="' + (String) url + '"';
            if (target != null) {
                link += ' target="' + (String) target + '"';
            }
            link += '>' + (String) friendlyText + '</a>';

            return link;
        }

        public override Arity getArity() {
            return Arity.between(2, 3);
        }
    }

    /**
     * @description Substitutes new text for old text in a text string.
     *
     * Accepts 3 arguments: the text to evaluate, the text to replace, and the text to replace it with.
     * @function SUBSTITUTE
     * @example
     * SUBSTITUTE("Hello World", "World", "Universe") // "Hello Universe"
     */
    private class SubstituteFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // Check that the first argument is a string
            Object text = evaluate(arguments.get(0));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SUBSTITUTE" function: the first argument must evaluate to a string value.'
                );
            }

            // Check that the second argument is a string
            Object oldText = evaluate(arguments.get(1));
            if (!(oldText instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SUBSTITUTE" function: the second argument must evaluate to a string value.'
                );
            }

            // Check that the third argument is a string
            Object newText = evaluate(arguments.get(2));
            if (!(newText instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SUBSTITUTE" function: the third argument must evaluate to a string value.'
                );
            }

            // Replace all occurrences of the old text with the new text
            return ((String) text).replaceAll((String) oldText, (String) newText);
        }

        public override Arity getArity() {
            return Arity.exactly(3);
        }
    }

    /**
     * @description Converts a value to text.
     *
     * Accepts 1 argument: the value to convert.
     * @function TEXT
     * @example
     * TEXT(123) // "123"
     */
    private class TextFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object value = evaluate(arguments.get(0));
            return StringUtils.valueOf(value);
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Removes the spaces and tabs from the beginning and end of a text string.
     *
     * Accepts 1 argument: the text to trim.
     * @function TRIM
     * @example
     * TRIM(" Hello World ") // "Hello World"
     */
    private class TrimFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // The argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "TRIM" function: the argument must evaluate to a string value.'
                );
            }

            return ((String) value).trim();
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Converts all letters in the specified text to uppercase.
     *
     * Accepts 1 argument: the text to convert.
     * @function UPPER
     * @example
     * UPPER("Hello World") // "HELLO WORLD"
     */
    private class UpperFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // The argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "UPPER" function: the argument must evaluate to a string value.'
                );
            }

            return ((String) value).toUpperCase();
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Converts a text string that represents a number to a number.
     *
     * Accepts 1 argument: the text to convert.
     * @function VALUE
     * @example
     * VALUE("123") // 123
     */
    private class ValueFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // The argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "VALUE" function: the argument must evaluate to a string value.'
                );
            }

            return Decimal.valueOf((String) value);
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Returns a list that contains each substring of the String that is terminated
     * by the provided delimiter.
     *
     * Accepts 2 arguments: the text to split and the delimiter.
     * @function SPLIT
     * @example
     * SPLIT("Hello World", " ") // ["Hello", "World"]
     */
    private class SplitFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // First argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SPLIT" function: the first argument must evaluate to a string value.'
                );
            }

            // Second argument must be a string
            Object delimiter = evaluate(arguments.get(1));
            if (!(delimiter instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "SPLIT" function: the second argument must evaluate to a string value.'
                );
            }

            return ((String) value).split((String) delimiter);
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }
    }

    /**
     * @description Converts the first letter of each word in a text string to uppercase and converts all other letters to lowercase.
     *
     * Accepts 1 argument: the text to convert.
     * @function INITCAP
     * @example
     * INITCAP("hello world") // "Hello World"
     */
    private class InitCapFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // The argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "INITCAP" function: the argument must evaluate to a string value.'
                );
            }

            String[] words = ((String) value).split(' ');
            String result = '';
            for (Integer i = 0; i < words.size(); i++) {
                result += words[i].substring(0, 1).toUpperCase() + words[i].substring(1).toLowerCase();
                if (i < words.size() - 1) {
                    result += ' ';
                }
            }

            return result;
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Encodes text and merge field values for use in URLs by replacing characters that are illegal in URLs, such as blank
     * spaces.
     *
     * Accepts 1 argument: the text to encode.
     * @function URLENCODE
     * @example
     * URLENCODE("Hello World") // "Hello+World"
     */
    private class UrlEncodeFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            // The argument must be a string
            Object value = evaluate(arguments.get(0));
            if (!(value instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "URLENCODE" function: the argument must evaluate to a string value.'
                );
            }

            return EncodingUtil.urlEncode((String) value, 'UTF-8');
        }

        public override Arity getArity() {
            return Arity.exactly(1);
        }
    }

    /**
     * @description Returns TRUE if a text field matches a given pattern.
     * The pattern can include regular characters and wildcard characters.
     * The supported wildcard characters are the percent sign (%), which matches zero or more characters, and the underscore (_),
     * which matches exactly one character.
     *
     * Accepts 2 arguments: the text field and the pattern to match.
     * @function LIKE
     * @example
     * LIKE("Hello World", "Hello%") // TRUE
     * LIKE("Hello World", "Hello_") // FALSE
     */
    private class LikeFn extends StandardFunction {
        public override Object call(List<Expr> arguments) {
            Object text = evaluate(arguments.get(0));
            Object pattern = evaluate(arguments.get(1));
            if (!(text instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "LIKE" function: the first argument must evaluate to a string value.'
                );
            }
            if (!(pattern instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "LIKE" function: the second argument must evaluate to a string value.'
                );
            }

            return matchesPattern((String) text, (String) pattern);
        }

        public override Arity getArity() {
            return Arity.exactly(2);
        }

        private Boolean matchesPattern(String text, String targetPattern) {
            // Escape special regex characters
            targetPattern = targetPattern.replaceAll('([\\\\.\\[\\{\\(\\*\\+\\?\\^\\$\\|])', '\\\\$1');
            // Replace SQL wildcards with regex wildcards
            targetPattern = targetPattern.replaceAll('%', '.*').replaceAll('_', '.');
            // Create a new Pattern object
            Pattern regex = Pattern.compile('^' + targetPattern + '$');
            // Test the text against the pattern
            Matcher matcher = regex.matcher(text);
            return matcher.matches();
        }
    }

    /**
     * @description Evaluates a string expression dynamically and returns the result.
     *
     * Accepts 1 or 2 arguments:
     * 1. The string expression to evaluate
     * 2. (Optional) The context object to use for evaluation. Can be an SObject, a record ID, or a variable reference
     *
     * The function can access the current context for fields and add them to the context if they don't exist.
     * @function EVAL
     * @example
     * EVAL("1 + 2") // 3
     * EVAL("'Hello ' + 'World'") // "Hello World"
     * EVAL("@Context.FirstName + ' ' + @Context.LastName") // Concatenates two context fields
     * EVAL("Description") // Evaluates Description field in current context (e.g., current quote line item)
     * EVAL("Number", @Context.Quote) // Evaluates Number field in parent Quote context
     * 
     * When used with MAP, each item becomes the context:
     * MAP(QuoteLineItems, EVAL("Description")) // Description from each line item
     * MAP(QuoteLineItems, EVAL("@Context.Quote.Name")) // Parent quote name for each line item
     */
    private class EvalFn extends StandardFunction {
        // Counter to track cache hits
        private Integer cacheHits = 0;
        
        public override Object call(List<Expr> arguments) {
            // Check that the first argument is a string
            Object expressionArg = evaluate(arguments.get(0));
            if (!(expressionArg instanceof String)) {
                throw new FunctionExecutionException(
                    'Error executing "EVAL" function: the first argument must evaluate to a string value.'
                );
            }

            String expressionString = (String) expressionArg;
            
            // Check for optional second argument - the context
            SObject contextSObject = null;
            Id contextRecordId = null;
            Object customContextObj = null;
            
            if (arguments.size() > 1) {
                Object contextArg = evaluate(arguments.get(1));
                System.debug(LoggingLevel.INFO, 'EVAL function - Context argument provided: ' + 
                           (contextArg != null ? contextArg.toString() : 'null'));
                
                // Determine type of context
                if (contextArg instanceof SObject) {
                    contextSObject = (SObject)contextArg;
                    if (contextSObject.Id != null) {
                        contextRecordId = contextSObject.Id;
                    }
                    System.debug(LoggingLevel.INFO, 'EVAL function - Using explicit SObject context: ' + 
                               contextSObject.getSObjectType() + (contextRecordId != null ? ' ID: ' + contextRecordId : ''));
                } else if (contextArg instanceof Id) {
                    contextRecordId = (Id)contextArg;
                    System.debug(LoggingLevel.INFO, 'EVAL function - Using explicit ID context: ' + contextRecordId);
                } else {
                    // Store as custom context
                    customContextObj = contextArg;
                    System.debug(LoggingLevel.INFO, 'EVAL function - Using explicit custom context: ' + 
                               (customContextObj != null ? customContextObj.toString() : 'null'));
                }
            }
            
            System.debug(LoggingLevel.INFO, 'EVAL function - Expression to evaluate: ' + expressionString);
            
            try {
                // Check if we have an interpreter (which should have been set by FunctionCaller)
                if (interpreter == null) {
                    System.debug(LoggingLevel.ERROR, 'EVAL function - No interpreter available');
                    throw new FunctionExecutionException('Error executing "EVAL" function: No interpreter available');
                }
                System.debug(LoggingLevel.INFO, 'EVAL function - Got interpreter');
                
                // Get the current environment which contains the context
                Environment currentEnv = interpreter.getEnvironment();
                if (currentEnv == null) {
                    System.debug(LoggingLevel.ERROR, 'EVAL function - Current environment is null');
                    throw new FunctionExecutionException('Error executing "EVAL" function: No environment available');
                }
                
                System.debug(LoggingLevel.INFO, 'EVAL function - Got current environment');
                
                // Get contextual data from environment if not already provided by second argument
                if (contextSObject == null && contextRecordId == null && customContextObj == null) {
                    try {
                        if (currentEnv.contains('@context')) {
                            Object contextObj = currentEnv.get('@context');
                            System.debug(LoggingLevel.INFO, 'EVAL function - Found @context: ' + 
                                       (contextObj != null ? contextObj.toString() : 'null'));
                            
                            if (contextObj instanceof SObject) {
                                contextSObject = (SObject)contextObj;
                                if (contextSObject.Id != null) {
                                    contextRecordId = contextSObject.Id;
                                }
                                System.debug(LoggingLevel.INFO, 'EVAL function - Context is SObject: ' + 
                                           contextSObject.getSObjectType());
                            } else if (contextObj instanceof Id) {
                                contextRecordId = (Id)contextObj;
                                System.debug(LoggingLevel.INFO, 'EVAL function - Context is ID: ' + contextRecordId);
                            } else {
                                customContextObj = contextObj;
                                System.debug(LoggingLevel.INFO, 'EVAL function - Context is custom: ' + 
                                           (customContextObj != null ? customContextObj.toString() : 'null'));
                            }
                        } else {
                            System.debug(LoggingLevel.INFO, 'EVAL function - No @context found in environment');
                        }
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'EVAL function - Error accessing @context: ' + e.getMessage());
                    }
                }
                
                // Create a configuration with diagnostics enabled
                Configuration config = new Configuration();
                config.withDiagnostics(); // Enable diagnostics for debugging
                
                // Get context variables from the environment
                Map<String, Object> contextMap = new Map<String, Object>();
                
                // If there's an explicitly provided custom context, prioritize it
                if (customContextObj != null) {
                    // Add the object itself as "context"
                    contextMap.put('context', customContextObj);
                    
                    // If it's a map, also add its entries
                    if (customContextObj instanceof Map<String, Object>) {
                        Map<String, Object> contextAsMap = (Map<String, Object>)customContextObj;
                        contextMap.putAll(contextAsMap);
                        System.debug(LoggingLevel.INFO, 'EVAL function - Added ' + contextAsMap.size() + 
                                   ' keys from explicit context map');
                    }
                } 
                // Otherwise collect context from the environment
                else if (currentEnv != null) {
                    // Look for context variables in the environment
                    for (String varName : getEnvironmentVariables(currentEnv)) {
                        if (varName.startsWith('@')) {
                            try {
                                if (currentEnv.contains(varName)) {
                                    Object value = currentEnv.get(varName);
                                    String contextKey = varName.substring(1); // Remove @ prefix
                                    contextMap.put(contextKey, value); 
                                    String valueStr = value != null ? String.valueOf(value) : 'null';
                                    if (valueStr.length() > 100) {
                                        valueStr = valueStr.substring(0, 97) + '...';
                                    }
                                    System.debug(LoggingLevel.INFO, 'EVAL function - Adding context variable: ' + 
                                               varName + ' = ' + valueStr);
                                }
                            } catch (Exception e) {
                                System.debug(LoggingLevel.ERROR, 'EVAL function - Error accessing variable ' + 
                                           varName + ': ' + e.getMessage());
                            }
                        }
                    }
                }
                
                // If we have an explicit context SObject, make sure it's included
                if (contextSObject != null) {
                    contextMap.put('context', contextSObject);
                    if (contextRecordId != null) {
                        contextMap.put('id', contextRecordId);
                    }
                }
                
                // Add the context map to the configuration
                if (!contextMap.isEmpty()) {
                    config.withCustomContext(contextMap);
                    System.debug(LoggingLevel.INFO, 'EVAL function - Added ' + contextMap.size() + 
                               ' context variables to the evaluation');
                }
                
                // Pre-analyze the expression to retrieve all fields we're going to need
                try {
                    // Determine which ID to use for record lookup and caching
                    Id recordId = null;
                    
                    // First priority: explicit ID passed as context
                    if (contextRecordId != null) {
                        recordId = contextRecordId;
                        System.debug(LoggingLevel.INFO, 'EVAL function - Using explicit context ID: ' + recordId);
                    }
                    // Second priority: ID from explicit SObject
                    else if (contextSObject != null && contextSObject.Id != null) {
                        recordId = contextSObject.Id;
                        System.debug(LoggingLevel.INFO, 'EVAL function - Using ID from explicit context record: ' + recordId);
                    }
                    // Third priority: ID from environment
                    else if (currentEnv != null && currentEnv.contains('@id') && currentEnv.get('@id') instanceof Id) {
                        recordId = (Id)currentEnv.get('@id');
                        System.debug(LoggingLevel.INFO, 'EVAL function - Using ID from environment: ' + recordId);
                    }
                    
                    // If we have a record ID, check if we already have an enriched version in cache
                    if (recordId != null) {
                        // Create a unique key for this expression + record combination
                        String normalizedExpression = expressionString.trim().toLowerCase();
                        String cacheKey = recordId + ':' + normalizedExpression;
                        
                        System.debug(LoggingLevel.INFO, 'EVAL function - Cache key: ' + cacheKey);
                        System.debug(LoggingLevel.INFO, 'EVAL function - Completed queries: ' + COMPLETED_QUERIES.size());
                        
                        // If we've already successfully handled this exact expression for this record, skip querying
                        if (COMPLETED_QUERIES.contains(cacheKey)) {
                            cacheHits++;
                            System.debug(LoggingLevel.INFO, 'EVAL function - *** CACHE HIT! *** Already completed this exact query: ' + cacheKey);
                            
                            // Simply use the cached record for evaluation
                            SObject cachedRecord = CACHED_RECORDS.get(recordId);
                            if (cachedRecord != null) {
                                System.debug(LoggingLevel.INFO, 'EVAL function - Using cached record with fields: ' + 
                                           cachedRecord.getPopulatedFieldsAsMap().keySet());
                                EvaluatorResolver evaluator = EvaluatorResolver.forRecord(cachedRecord);
                                
                                // Evaluate and return immediately to avoid any redundant processing
                                EvaluationResult result = evaluator.evaluate(expressionString, config);
                                System.debug(LoggingLevel.INFO, 'EVAL function - Evaluation result (from cache hit #' + cacheHits + '): ' + result.result);
                                return result.result;
                            }
                        }
                        
                        System.debug(LoggingLevel.INFO, 'EVAL function - Working with record ID: ' + recordId);
                        
                        // Determine exactly which fields are needed for this expression
                        Set<String> fieldsNeeded;
                        if (EXPRESSION_FIELD_CACHE.containsKey(expressionString)) {
                            fieldsNeeded = EXPRESSION_FIELD_CACHE.get(expressionString);
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using cached field list for expression: ' + fieldsNeeded);
                        } else {
                            fieldsNeeded = getFieldsFromExpression(expressionString);
                            EXPRESSION_FIELD_CACHE.put(expressionString, fieldsNeeded);
                            System.debug(LoggingLevel.INFO, 'EVAL function - Fields needed for expression: ' + fieldsNeeded);
                        }
                        
                        // First, try to get the record from our static cache
                        SObject enrichedRecord = null;
                        Boolean foundInCache = false;
                        Boolean needsRefresh = false;
                        
                        // Check if the record is in cache and has all needed fields
                        if (CACHED_RECORDS.containsKey(recordId)) {
                            enrichedRecord = CACHED_RECORDS.get(recordId);
                            foundInCache = true;
                            
                            if (enrichedRecord != null) {
                                Set<String> fieldsInRecord = enrichedRecord.getPopulatedFieldsAsMap().keySet();
                                System.debug(LoggingLevel.INFO, 'EVAL function - Found record in cache with fields: ' + fieldsInRecord);
                                
                                // Check if ALL needed fields are already in the cached record
                                Boolean allFieldsInCache = true;
                                for (String field : fieldsNeeded) {
                                    if (!fieldsInRecord.contains(field.toLowerCase())) {
                                        System.debug(LoggingLevel.INFO, 'EVAL function - Field not in cache: ' + field);
                                        allFieldsInCache = false;
                                        break;
                                    }
                                }
                                
                                // If we have all fields, we're done!
                                if (allFieldsInCache) {
                                    System.debug(LoggingLevel.INFO, 'EVAL function - All needed fields found in cache, NO QUERY NEEDED');
                                    EvaluatorResolver evaluator = EvaluatorResolver.forRecord(enrichedRecord);
                                    // Mark this query as completed
                                    COMPLETED_QUERIES.add(cacheKey);
                                    
                                    // Evaluate and return immediately
                                    EvaluationResult result = evaluator.evaluate(expressionString, config);
                                    System.debug(LoggingLevel.INFO, 'EVAL function - Evaluation result (all fields in cache): ' + result.result);
                                    return result.result;
                                } else {
                                    needsRefresh = true;
                                }
                            } else {
                                needsRefresh = true;
                            }
                        } else {
                            needsRefresh = true;
                        }
                        
                        // Prevent excessive queries by enforcing a time limit between queries for the same record
                        Long currentTime = System.currentTimeMillis();
                        if (LAST_QUERY_TIME_BY_RECORD_ID.containsKey(recordId)) {
                            Long lastQueryTime = LAST_QUERY_TIME_BY_RECORD_ID.get(recordId);
                            Long timeSinceLastQuery = currentTime - lastQueryTime;
                            
                            // If it's been less than 100ms since our last query, use what we have instead of querying again
                            if (timeSinceLastQuery < 100 && foundInCache) {
                                System.debug(LoggingLevel.INFO, 'EVAL function - THROTTLING QUERY - Last query was ' + 
                                           timeSinceLastQuery + 'ms ago, using cached data');
                                EvaluatorResolver evaluator = EvaluatorResolver.forRecord(enrichedRecord);
                                
                                // Evaluate and return immediately
                                EvaluationResult result = evaluator.evaluate(expressionString, config);
                                System.debug(LoggingLevel.INFO, 'EVAL function - Evaluation result (throttled): ' + result.result);
                                return result.result;
                            }
                        }
                        
                        // If we need to refresh or don't have the record cached
                        if (needsRefresh) {
                            System.debug(LoggingLevel.INFO, 'EVAL function - Querying for fields needed by expression');
                            LAST_QUERY_TIME_BY_RECORD_ID.put(recordId, currentTime);
                            
                            SObject freshRecord = EvaluatorResolver.retrieveRecordForFormulas(
                                recordId, new List<String>{ expressionString }
                            );
                            
                            if (freshRecord != null) {
                                if (foundInCache && enrichedRecord != null) {
                                    // Merge the fresh record with the cached one to get all fields
                                    Map<String, Object> existingFields = enrichedRecord.getPopulatedFieldsAsMap();
                                    for (String field : freshRecord.getPopulatedFieldsAsMap().keySet()) {
                                        if (!existingFields.containsKey(field)) {
                                            enrichedRecord.put(field, freshRecord.get(field));
                                        }
                                    }
                                    System.debug(LoggingLevel.INFO, 'EVAL function - Updated cached record with new fields: ' + 
                                               freshRecord.getPopulatedFieldsAsMap().keySet());
                                } else {
                                    // Use the fresh record directly
                                    enrichedRecord = freshRecord;
                                    System.debug(LoggingLevel.INFO, 'EVAL function - Using freshly queried record with fields: ' + 
                                               enrichedRecord.getPopulatedFieldsAsMap().keySet());
                                }
                                
                                // Update the cache
                                CACHED_RECORDS.put(recordId, enrichedRecord);
                                
                                // Mark this query as completed so we don't repeat it
                                COMPLETED_QUERIES.add(cacheKey);
                            }
                        }
                        
                        // Use the enriched record for evaluation if we have one
                        if (enrichedRecord != null) {
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using record for evaluation with fields: ' + 
                                       enrichedRecord.getPopulatedFieldsAsMap().keySet());
                            EvaluatorResolver evaluator = EvaluatorResolver.forRecord(enrichedRecord);
                            EvaluationResult result = evaluator.evaluate(expressionString, config);
                            System.debug(LoggingLevel.INFO, 'EVAL function - Evaluation result: ' + result.result);
                            return result.result;
                        }
                    }
                    
                    // Choose the right evaluation approach based on available context
                    EvaluatorResolver evaluator;
                    
                    // Special handling for SObject context for best field resolution
                    if (contextSObject != null) {
                        System.debug(LoggingLevel.INFO, 'EVAL function - Using SObject with ID: ' + contextSObject.Id);
                        
                        // Try to use forId when possible to allow field querying
                        if (contextSObject.Id != null) {
                            // This will allow dynamic field querying when needed
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using forId evaluator for dynamic field querying');
                            evaluator = EvaluatorResolver.forId(contextSObject.Id);
                        } else {
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using forRecord evaluator (no dynamic field querying)');
                            evaluator = EvaluatorResolver.forRecord(contextSObject);
                        }
                    } else {
                        // Check if we can still find an ID in the context
                        Id contextId = null;
                        try {
                            if (currentEnv.contains('@id')) {
                                Object idValue = currentEnv.get('@id');
                                if (idValue instanceof Id) {
                                    contextId = (Id)idValue;
                                    System.debug(LoggingLevel.INFO, 'EVAL function - Found @id: ' + contextId);
                                }
                            }
                        } catch (Exception e) {
                            System.debug(LoggingLevel.ERROR, 'EVAL function - Error accessing @id: ' + e.getMessage());
                        }
                        
                        if (contextId != null) {
                            // We have an ID but no record, use forId to allow dynamic field querying
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using forId evaluator with ID: ' + contextId);
                            evaluator = EvaluatorResolver.forId(contextId);
                        } else {
                            System.debug(LoggingLevel.INFO, 'EVAL function - Using without context evaluation (no dynamic field querying)');
                            evaluator = EvaluatorResolver.withoutContext();
                        }
                    }
                    
                    // Evaluate using the chosen approach
                    EvaluationResult result = evaluator.evaluate(expressionString, config);
                    System.debug(LoggingLevel.INFO, 'EVAL function - Evaluation result: ' + result.result);
                    return result.result;
                    
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'EVAL function - Error pre-analyzing expression: ' + e.getMessage());
                    // Fall back to simple evaluation without context
                    EvaluatorResolver evaluator = EvaluatorResolver.withoutContext();
                    EvaluationResult result = evaluator.evaluate(expressionString, config);
                    return result.result;
                }
                
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'EVAL function - Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
                throw new FunctionExecutionException(
                    'Error executing "EVAL" function: ' + e.getMessage()
                );
            }
        }
        
        // Helper method to get environment variables
        private Set<String> getEnvironmentVariables(Environment env) {
            Set<String> variables = new Set<String>();
            
            // First, check basic context variables we know should be available in most environments
            variables.add('@context');
            variables.add('@id');
            variables.add('@ids');
            variables.add('@user');
            variables.add('@record');
            
            // Add other common context variables
            variables.add('@firstname');
            variables.add('@lastname');
            variables.add('@name');
            variables.add('@email');
            variables.add('@phone');
            variables.add('@recordtype');
            variables.add('@owner');
            variables.add('@createddate');
            variables.add('@lastmodifieddate');
            
            // Log presence of any context variables
            System.debug(LoggingLevel.INFO, 'EVAL function - Checking for context variables');
            for (String varName : variables) {
                try {
                    if (env.contains(varName)) {
                        System.debug(LoggingLevel.INFO, 'EVAL function - Found context variable: ' + varName);
                    }
                } catch (Exception e) {
                    // Ignore errors on missing variables
                    System.debug(LoggingLevel.FINE, 'EVAL function - Error checking variable ' + varName + ': ' + e.getMessage());
                }
            }
            
            return variables;
        }
        
        // Helper method to extract field names from an expression string
        private Set<String> getFieldsFromExpression(String expressionString) {
            Set<String> fields = new Set<String>();
            
            try {
                // Simple pattern-based extraction of potential field references in the form @Context.FieldName
                Pattern fieldPattern = Pattern.compile('@Context\\.(\\w+)');
                Matcher fieldMatcher = fieldPattern.matcher(expressionString);
                
                while (fieldMatcher.find()) {
                    String fieldName = fieldMatcher.group(1);
                    fields.add(fieldName);
                    System.debug(LoggingLevel.INFO, 'EVAL function - Extracted field from expression: ' + fieldName);
                }
                
                // If it's a simple expression that might just be a field name without @Context.
                if (expressionString.indexOf('.') == -1 && 
                    expressionString.indexOf('(') == -1 && 
                    expressionString.indexOf('+') == -1 &&
                    expressionString.indexOf('-') == -1 &&
                    expressionString.indexOf('*') == -1 &&
                    expressionString.indexOf('/') == -1 &&
                    expressionString.indexOf('\"') == -1 &&
                    expressionString.indexOf('\'') == -1) {
                    // This might be a direct field reference like "Name"
                    String potentialField = expressionString.trim();
                    if (!String.isBlank(potentialField)) {
                        fields.add(potentialField);
                        System.debug(LoggingLevel.INFO, 'EVAL function - Added potential direct field reference: ' + potentialField);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'EVAL function - Error extracting fields: ' + e.getMessage());
            }
            
            return fields;
        }

        public override Arity getArity() {
            return Arity.between(1, 2); // 1 required argument, 1 optional context argument
        }
    }
}