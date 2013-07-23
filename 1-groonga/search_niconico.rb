# -*- coding: utf-8 -*-
require 'groonga'
require 'json'

Encoding.default_external = 'utf-8'
Groonga::Context.default_options = {:encoding => :utf8}

Groonga::Database.open("./db/grn")

ruby_comments = Groonga["Comments"].select {|record| record.comment =~ "Ruby"}
puts ruby_comments.size
puts JSON.pretty_generate(ruby_comments.records)
