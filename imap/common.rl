// Copyright 2014, Georg Sauthoff <mail@georg.so>

/* {{{ GPLv3

    This file is part of imapdl.

    imapdl is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    imapdl is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with imapdl.  If not, see <http://www.gnu.org/licenses/>.

}}} */

%%{

machine imap_common;


# Parts of the IMAP protocol used both by the client and server side.
#
# The state machine description is derived from the IMAP4v1 formal syntax
# (RFC3501, Section 9, http://tools.ietf.org/html/rfc3501#section-9).
#
# The relevant grammar rules are included as comments, i.e. above each
# Ragel rule the relevant formal syntax snippet (in ABNF) is quoted as comment.
# For a description of the used augmented backus-naur form see RFC2234
# (http://tools.ietf.org/html/rfc2234) - which also contains some basic
# grammar rules used in RFC3501.


# NOTE: actions used is an included file does not necessarily
# have to be defined in the same file.
#
# For example, the cb_* callback actions have to be defined in the includer
# (before the inclusion location).
#
# The following actions are defined here because their implementation is generic.

# {{{ Actions

# for situation when we need to re-read the current character
# e.g. when returning via an error action
action return_minus
{
  // violates C standard when called on: *begin = ' ' and it matches ...
  // because p is decremented below the memory block start
  // only incremented it one above the block end is allowed by the standard
  //--p;
  // equivalent is:
  fhold;
  fret;
}

action buffer_clear
{
  buffer_.clear();
}
action buffer_start
{
  buffer_.start(p);
}
action buffer_start_next
{
  buffer_.start(p+1);
}
action buffer_stop
{
  buffer_.stop(p);
}
action buffer_cont
{
  buffer_.cont(p);
}
action buffer_finish
{
  buffer_.finish(p);
}
action buffer_add_char
{
  buffer_.cont(p);
  buffer_.stop(p+1);
}
action number_start
{
  number_buffer_.start(p);
  number_ = 0;
}
action number_finish
{
  number_buffer_.finish(p);
  number_ = boost::lexical_cast<uint32_t>(
      string(number_buffer_.begin(), number_buffer_.end()));
  literal_pos_ = 0;
}
action literal_tail_begin
{
  buffer_.cont(p);
}
action call_literal_tail
{
  if (number_) {
    if (convert_crlf_)
      fcall literal_tail_convert;
    else
      fcall literal_tail;
  }
}
action literal_tail_cond_return
{
  ++literal_pos_;
  if (literal_pos_ == number_) {
    buffer_.finish(p+1);
    fret;
  }
}
action cb_quoted_char
{
  cb_.imap_quoted_char(fc);
}

# }}}

include abnf "rfc/abnf.rl";

include literal_converter "imap/literal_converter.rl";

# resp-specials   = "]"

resp_specials = ']' ;

# quoted-specials = DQUOTE / "\"

quoted_specials = DQUOTE | '\\' ;

# list-wildcards  = "%" / "*"

list_wildcards = [%*] ;

# atom-specials   = "(" / ")" / "{" / SP / CTL / list-wildcards /
#                   quoted-specials / resp-specials

atom_specials = [(){] | SP | CTL | list_wildcards | quoted_specials
              | resp_specials ;

# ATOM-CHAR       = <any CHAR except atom-specials>

ATOM_CHAR    =  CHAR - atom_specials ;

# atom            = 1*ATOM-CHAR

atom = ATOM_CHAR+ ;

# number          = 1*DIGIT
#                    ; Unsigned 32-bit integer
#                    ; (0 <= n < 4,294,967,296)

number = DIGIT{1,10} >number_start %number_finish ;

# nz-number       = digit-nz *DIGIT
#                    ; Non-zero unsigned 32-bit integer
#                    ; (0 < n < 4,294,967,296)

nz_number = (digit_nz DIGIT {0,10} ) >number_start %number_finish ;

# literal         = "{" number "}" CRLF *CHAR8
#                    ; Number represents the number of CHAR8s

#literal = '{' number '}' CRLF CHAR8* ;

literal_tail := (CHAR8*) >literal_tail_begin $literal_tail_cond_return;

# convert_literal_tail is defined in imap/literal_converter.rl
literal_tail_convert := convert_literal_tail;

literal = '{' number >number_start %number_finish '}' CRLF @buffer_clear  @call_literal_tail ;

# QUOTED-CHAR     = <any TEXT-CHAR except quoted-specials> /
#                   "\" quoted-specials

QUOTED_CHAR = ( TEXT_CHAR - quoted_specials ) @cb_quoted_char
            | '\\' quoted_specials @cb_quoted_char ;

# quoted          = DQUOTE *QUOTED-CHAR DQUOTE

# quoted = DQUOTE QUOTED_CHAR* DQUOTE ;

# seems that there may be only one state chart per machine
# quoted_tail =
#   start: (
#     (TEXT_CHAR - quoted_specials)+   >buffer_cont %buffer_stop -> start |
#     '\\' quoted_specials             @buffer_add_char             -> start |
#     DQUOTE                           @buffer_finish                  -> final
#   );

# ** = longest-match Kleene Star
quoted_tail =
   (
     (TEXT_CHAR - quoted_specials)+   >buffer_cont %buffer_stop |
     ('\\' quoted_specials @buffer_add_char )
   ) **
   DQUOTE  @buffer_finish ;

quoted = DQUOTE @buffer_start_next quoted_tail ;

# string          = quoted / literal

string = quoted | literal ;

# ASTRING-CHAR   = ATOM-CHAR / resp-special

ASTRING_CHAR = ATOM_CHAR | resp_specials ;


# astring         = 1*ASTRING-CHAR / string

astring         = ASTRING_CHAR+ >buffer_start %buffer_finish | string ;

# nil             = "NIL"

nil = /NIL/i ;


# nstring         = string / nil

nstring = string | nil ;





# tag             = 1*<any ASTRING-CHAR except "+">

tag  = ( ASTRING_CHAR - '+' ) + ;

# date-day-fixed  = (SP DIGIT) / 2DIGIT
#                    ; Fixed-format version of date-day

date_day_fixed  = ( SP DIGIT ) | DIGIT {2} ;

# date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
#                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"

date_month = /Jan/i | /Feb/i | /Mar/i | /Apr/i | /May/i | /Jun/i |
             /Jul/i | /Aug/i | /Sep/i | /Oct/i | /Nov/i | /Dec/i ;

# date-year       = 4DIGIT

date_year = DIGIT {4} ;

# time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
#                     ; Hours minutes seconds

time = DIGIT {2} ':' DIGIT {2} ':' DIGIT {2} ;

# zone            = ("+" / "-") 4DIGIT
#                     ; Signed four-digit value of hhmm representing
#                     ; hours and minutes east of Greenwich (that is,
#                     ; the amount that the given time differs from
#                     ; Universal Time).  Subtracting the timezone
#                     ; from the given time will give the UT form.
#                     ; The Universal Time zone is "+0000".

zone = ( '+' | '-' ) DIGIT {4} ;

# date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
#                   SP time SP zone DQUOTE

date_time = DQUOTE date_day_fixed '-' date_month '-' date_year
            SP time SP zone DQUOTE ;

# flag-extension  = "\" atom
#                    ; Future expansion.  Client implementations
#                    ; MUST accept flag-extension flags.  Server
#                    ; implementations MUST NOT generate
#                    ; flag-extension flags except as defined by
#                    ; future standard or standards-track
#                    ; revisions of this specification.

flag_extension = '\\' atom ;

# flag-keyword    = atom

flag_keyword = atom ;

non_extensions = /Answered/i
               | /Flagged/i
               | /Deleted/i
               | /Seen/i
               | /Draft/i
               | /Recent/i ;

# flag            = "\Answered" / "\Flagged" / "\Deleted" /
#                  "\Seen" / "\Draft" / flag-keyword / flag-extension
#                    ; Does not include "\Recent"

# assuming that those flags are case insensitive like most other tokens ...
flag = (
       ( '\\' >buffer_start
              ( /Answered/i %buffer_finish %cb_flag_answered
              | /Flagged/i  %buffer_finish %cb_flag_flagged
              | /Deleted/i  %buffer_finish %cb_flag_deleted
              | /Seen/i     %buffer_finish %cb_flag_seen
              | /Draft/i    %buffer_finish %cb_flag_draft
              # flag_extension
              | (atom - non_extensions) %buffer_finish %cb_flag_atom
              )
       )
     | flag_keyword >buffer_start %buffer_finish )
     ;


# flag-list       = "(" [flag *(SP flag)] ")"

flag_list = '(' (flag (SP flag)* )? ')' ;

# status-att      = "MESSAGES" / "RECENT" / "UIDNEXT" / "UIDVALIDITY" /
#                   "UNSEEN"

status_att = /MESSAGES/i
           | /RECENT/i
           | /UIDNEXT/i
           | /UIDVALIDITY/i
           | /UNSEEN/i ;

# mailbox         = "INBOX" / astring
#                     ; INBOX is case-insensitive.  All case variants of
#                     ; INBOX (e.g., "iNbOx") MUST be interpreted as INBOX
#                     ; not as an astring.  An astring which consists of
#                     ; the case-insensitive sequence "I" "N" "B" "O" "X"
#                     ; is considered to be INBOX and not an astring.
#                     ;  Refer to section 5.1 for further
#                     ; semantic details of mailbox names.

mailbox = /INBOX/i | ( astring ) ;

# header-fld-name = astring

header_fld_name = astring ;

# header-list     = "(" header-fld-name *(SP header-fld-name) ")"

header_list = '(' header_fld_name (SP header_fld_name)* ')' ;

# section-msgtext = "HEADER" / "HEADER.FIELDS" [".NOT"] SP header-list /
#                   "TEXT"
#                     ; top-level or MESSAGE/RFC822 part

section_msgtext = /HEADER/i %cb_section_header
                | /HEADER.FIELDS/i (/.NOT/i)? SP header_list
                | /TEXT/i ;

# section-part    = nz-number *("." nz-number)
#                    ; body part nesting

section_part = nz_number ( '.' nz_number )* ;

# section-text    = section-msgtext / "MIME"
#                    ; text other than actual body part (headers, etc.)

section_text = section_msgtext
             | /MIME/i ;

# section-spec    = section-msgtext / (section-part ["." section-text])

section_spec = section_msgtext
             | section_part ( '.' section_text)? ;

# section         = "[" [section-spec] "]"

section = '[' @cb_body_section_begin
             ( section_spec ']' | ']' @cb_section_empty ) ;

# RFC 2971 - IMAP4 ID extension

# id_params_list ::= "(" #(string SPACE nstring) ")" / nil
#         ;; list of field value pairs

id_params_list = '(' (string SP nstring) (SP string SP nstring)* ')' | nil
  ;


}%%


