# /Users/casiano/Dropbox/src/PL/simple_rec_descent_parser

module Calc
  module Tokens
    COMOP      = 0
    OPERATOR   = 1
    NUMBER     = 2
    ID         = 3
    COMA       = 4
    UNEXPECTED = 5
    EOI        = 6

    
    NAME = {
      0 => :COMOP,
      1 => :OPERATOR,   
      2 => :NUMBER,    
      3 => :ID, 
      4 => :COMA,
      5 => :UNEXPECTED,
      6 => :EOI,

    }
  end

  class Token
    include Tokens
    attr_accessor :token, :value

    def initialize(token, value=token)
      @token, @value = token, value
    end

    def to_s
      "(#{NAME[token]}, '#{value}')"
    end
  end

  class Parser
    include Tokens
    attr_accessor :input, :lexer, :current_token

    def initialize(input = '')
      @input = input                 

      @regexp = %r{
	  (<=|>=|==|!=|[<>])          #COMOP
         |  ([-+*/()=;])              # OPERATOR 
         | (\d+)                     # NUMBER
         | ([a-zA-Z_]\w*)            # ID 
	 | ([,])                     #COMA
         |(\S)                       # UNEXPECTED
	 
      }x

      @lexer = Fiber.new do
         input.scan(@regexp) do |par|  # [ nil, nil, 'a', nil ]
           t = (0..par.length-1).select { |x| !par[x].nil? }  # [ 2 ]
           t = t.shift                 # 2
           v = par[t]                  # 'a'
           if  t == UNEXPECTED
             warn "Unexpected '#{v}' after '#$`'" 
           else
             Fiber.yield Token.new(t, v)
           end
         end
         Fiber.yield  Token.new(EOI, nil)
      end

      next_token 

    end

    def input=(val)
      @input = val
      next_token if input.length > 0
    end

    def match_val(v)
      if (v == current_token.value)
        next_token
      else
        raise SyntaxError, "Syntax error. Expected '#{v}', found '#{current_token}'"
      end
    end

    def next_token
       @current_token = @lexer.resume
    end

    # Operator '=' is right associative
    def assignment     # assignment --> comparison '=' assignment | comparison
      val = comparison
      if (current_token.value == '=') 
        raise SyntaxError, "Error. Expected left-value, found #{val}" unless  val =~ /^[a-z_A-Z]\w*$/
        next_token
        "#{val} #{assignment} ="
      else
        val
      end
    end
    
    # Operators < >  <= >= != ==
    def comparison      #comparison  --> comparison COMOP expression  |  comparison
      exp = expression
      lookahead,sem = current_token.token, current_token.value
      if lookahead == COMOP then
	next_token
	exp2 = expression
	exp += " #{exp2} #{sem}"
      end
      exp
    end

    def expression   # expression --> expresion /^[+-]$/ term | term
      t1 = term
      val = "#{t1}"  # expression --> term ( /^[+-]$/ term ) *
      while (current_token.value =~ /^[+-]$/) 
        op = current_token.value
        next_token
        t2 = term
        val += " #{t2} #{op}"
      end
      val
    end

    def term     # term --> term /^[*/]$/ factor | factor
      f = factor
      val = "#{f}"    # term --> factor (/^[*/]$/ factor) *
      while (current_token.value =~ %r{^[*/]$}) 
        op = current_token.value
        next_token
        t = factor
        val += " #{t} #{op}"
      end
      val
    end

#   factor       : NUMBER
#              | '(' assignment ')'
#              | ID resto
    def factor
      lookahead, sem  = current_token.token, current_token.value
      case lookahead 
        when NUMBER
          next_token
          sem
        when ID
	  next_token
	  r = resto
	  val = "#{r} #{sem}"
          #next_token
          #sem
        else
          if sem == '(' then
            next_token
            e = assignment()
            match_val(')')
            e
          else
            raise SyntaxError, "Syntax error. Expected NUMBER or ID or '(', found #{current_token}"
          end
      end
    end
    
# resto        :  € #vacio
# 	     | '('listofargs ')'
    def resto
      lookahead, sem  = current_token.token, current_token.value

          if sem == '(' then
            next_token
            arg = listofargs()
            match_val(')')
            arg
	  end
	  #Si no entra es Cadena vacia
    end

# listofargs   : assigment
# 	     | assigment listofargs
    def listofargs
      l = assignment()
      val="#{l}"
      while (current_token.token == COMA) 
       # c = current_token.value
        next_token
        a = assignment()
        val += " #{a} ,"
      end
      val
    end
   
  end
  
  

    
    
    

  


  

  if $0 == __FILE__
    include Tokens

    input = ARGV.shift || 'a = ( 2 - 3 ) * 5'
    calc = Parser.new( input )
    postfix =  calc.assignment()
    raise SyntaxError, "Unexpected #{calc.current_token}\n" unless calc.current_token.token == EOI
    puts "The translation of '#{input}' to postfix is: #{postfix}"

    input = '3 * 5'
    calc = Parser.new( input )
    postfix =  calc.assignment()
    raise SyntaxError, "Unexpected #{calc.current_token}\n" unless calc.current_token.token == EOI
    puts "The translation of '#{input}' to postfix is: #{postfix}"
  end
end
