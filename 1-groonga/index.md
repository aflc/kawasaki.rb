![](./groonga-logo.png) 結構便利です
===================================




<small>The groonga project</small>


groongaって何？
---------------

* 名前の由来は「強そうだから」
* 全文検索エンジンSennaの後継

実体は
------

全文検索が得意なカラム志向のデータストア

どうやって使うの？
------------------

1. MySQL(MariaDB)にプラグインとして導入可能 => mroonga
    ストレージエンジンとして使うもよし、全文検索機能のみを使うもよし
1. PostgreSQL(あまり更新されてない？)
1. node.js => nroonga
1. 単体httpサーバーとして動く
1. Rubyから直接叩く(C-extension)
1. 専用プロトコル、memcachedプロトコル
1. C APIを利用する

ウリ
----

* 参照ロックフリー
  データの更新中に参照が出来る（ロックされない）
  頻繁にデータを変更する場合にはとても有利

* 高速なドリルダウン機能
  が標準機能になってる
  Solrではファセットと呼ばれているやつ
  Amazonとかでジャンルごとに検索結果の件数が出てくるアレ

* 位置情報検索が出来る
  * 内部でインデックス化するので検索が速いらしい
  * 試したこと無いけど

groongaを使っている有名？ドコロ
-------------------------------

* るりまサーチ
* buzztter
* Bizreach
* Milkode
* -> http://groonga.org/ja/users/

rroonga
-------

* Rubyから直接groongaライブラリを呼び出すラッパーライブラリ
* groongaの開発陣がメンテしてる（ため安定してる）
* 単なるファイルベースのKVSとして気軽に利用できる
  * ファイルベースのDBって意外にに選択肢が無い
    * levelDB
    * TokyoCabinet/KyotoCabinet
    * SQLite3
    * Berkley DB
    * (知ってたら教えて)

rroongaでのデモ
---------------

必要なことは

```
gem install rroonga
```

だけ！

groongaがインストールされていない場合は自動でソースを拾ってきてビルドします（ただしgroongaコマンドは無い）


サンプルデータ
--------------

せっかくなので「ニコニコ動画コメントなどデータ」を突っ込んでみよう

* 動画のメタデータとコメントがダウンロード出来ます
  * http://www.nii.ac.jp/cscenter/idr/nico/nico.html


データベースの作成
------------------

```ruby
require 'groonga'

# encodingの設定
Encoding.default_external = 'utf-8'
Groonga::Context.default_options = {:encoding => :utf8}

begin
  Groonga::Database.open("./db/grn")
rescue
  Groonga::Database.create(:path => "./db/grn")
end
```

スキーマ定義
------------

```ruby
Groonga::Schema.create_table("Tags", :type => :patricia_trie)
Groonga::Schema.create_table("Videos", :type => :hash) do |table|
  table.short_text("title")
  table.text("description")
  table.short_text("thumbnail_url")
  table.time("upload_time")
  table.uint32("length")
  table.short_text("movie_type")
  table.uint32("size_high")
  table.uint32("size_low")
  table.uint64("view_counter")
  table.uint64("comment_counter")
  table.uint64("mylist_counter")
  table.reference("taglist", "Tags", :type => :vector)
  table.reference("locked_taglist", "Tags", :type => :vector)
  table.reference("category_taglist", "Tags", :type => :vector)
end
```

スキーマ定義2
-------------

```ruby
Groonga::Schema.create_table("Comments", :type => :hash) do |table|
  table.reference("video", "Videos")
  table.time("date")
  table.uint64("no")
  table.uint64("vpos")
  table.short_text("comment")
  table.short_text("command")
end
```

データを突っ込む
----------------

```ruby
cmd = ARGV[0]
Dir.glob(File.join(cmd, "video/*.dat")) do |path|
  File.open(path).each do |line|
    j = JSON.parse(line)
    Groonga["Videos"].add(j["video_id"], :title => j["title"],
                                   :description => j["description"],
                                   :thumbnail_url => j["thumbnail_url"],
                                   :upload_time => j["upload_time"],
                                   :length => j["length"],
                                   :movie_type => j["movie_type"],
                                   :size_high => j["size_high"],
                                   :size_low => j["size_low"],
                                   :view_counter => j["view_counter"],
                                   :comment_counter => j["comment_counter"],
                                   :mylist_counter => j["mylist_counter"],
                                   :taglist => j["tags"].map{|x| x["tag"]},
                                   :locked_taglist => j["tags"].select{|x| x["lock"] == 1}.map{|x| x["tag"]},
                                   :category_taglist => j["tags"].select{|x| x["category"] == 1}.map{|x| x["tag"]}
                    )
  end
end
```

データを突っ込む2
-----------------

```ruby
Dir.glob(File.join(cmd, "thread/**/sm*.dat")) do |path|
  videoid = "sm" + Integer(path.match(/(\d+)\/sm(\d+).dat$/).captures.join, 10).to_s
  puts videoid
  File.open(path).each do |line|
    j = JSON.parse(line)
    primary_id = %Q!#{videoid}/#{j["no"]}!
    Groonga["Comments"].add(primary_id, :video => videoid,
                                        :date => j["date"],
                                        :no => j["no"],
                                        :vpos => j["vpos"],
                                        :comment => j["comment"],
                                        :command => j["command"]
                            )
  end
end
```

* 手元のMBA(2011)に9714112コメント（最初の0000ファイルだけ）入れてみて11分かかりました
  * ほぼCPU100%張り付き

全文検索インデックスを作る
--------------------------

```ruby
Groonga::Schema.create_table("CommentTerms",
                             :type => :patricia_trie,
                             :normalizer => :NormalizerAuto,
                             :default_tokenizer => "TokenBigram"   # TokenMecabもあるよ
                             ) do |table|
  table.index("Comments.comment")
end
```


検索して楽しむ
--------------

```ruby
ruby_comments = Groonga["Comments"].select {|record| record.comment =~ "Ruby"}
puts ruby_comments.size  # => 1
puts JSON.pretty_generate(ruby_comments.records)

# [
#   {
#     "_id": 1,
#     "_key": {
#       "_id": 5872107,
#       "_key": "sm9/465099",
#       "command": "big ue",
#       "comment": "Building Ruby, Rails, Subversion, Mongrel, and MySQL on Mac",
#       "date": "2007-04-08T01:39:36+09:00",
#       "no": 465099,
#       "video": {
#         "_id": 1628,
#         "_key": "sm9",
#         "category_taglist": [
# 
#         ],
#         "comment_counter": 4103378,
#         "description": "レッツゴー！陰陽師（フルコーラスバージョン）",
#         "length": 319,
#         ....
```


残念
----

* Python用のライブラリが無い
  * CAPIが用意されているが、ドキュメントなくて泣きたい

* ドキュメントがちゃんとしていると思いきやそうでもない

* rroongaにはGVLの問題がある
  * Issueは１年以上前にあるが放置(http://redmine.groonga.org/issues/1221)

* レプリケーションとかトランザクションとか本格的な運用に向けた機能は無い
  * FluentdやMuninとかと連携は出来るみたい


今後
----

* groonga++!!
  * marisa-trieが入る!!アツい!!
* C APIのドキュメント化が始まりました
  * 意味不明なAPIも多いので助かる（特にgrnexpr周り）

