import "strings"
import "text/template"


data: {
  text: string
}

_tmpl:
"""
{{ .text }}
"""

rendered: template.Execute(_tmpl, data)
