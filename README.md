# 電子書籍ツール for 『宗教学雑考集』
# E-Book Tools for "Religious Studies"

<!-- Time-stamp: "2025-02-05T18:01:59Z" -->

## このツールについて

拙著『宗教学雑考集』正式版(第1.0版)が 2025年3月11日に発売されます。その電子組版のために作ったツールを公開します。なお、JRF『宗教学雑考集 易理・始源論・神義論』は、[Amazon](https://www.amazon.co.jp/dp/B0DS54K2ZT)、[BOOK☆WALKER](https://bookwalker.jp/de319f05c6-3292-4c46-99e7-1e8e42269b60/)、[BOOTH](https://j-rockford.booth.pm/items/5358889)でお求めになれます。

ツールは Perl で作られています。入力 TXT ファイルの形式は後ほど説明します。

  * txt2epubhtml.pl: EPUB 用の HTML を生成します。HTML は Sigil に読み込みます。
  * make_tex.pl: PDF を生成するための lualatex 用 TeX を生成します。
  * gen_sample.pl: main.txt から sample.txt を抽出します。


## txt2epubhtml.pl

まず sample.txt をエディットします。そして、次のコマンドを実行すると、Section0001.xhtml が生成されます。

```sh
perl txt2epubhtml.pl sample.txt -o Section0001.xhtml
```

できた Section0001.xhtml を Sigil で開いた sample.epub の Section0001.xhtml にコピペして目次を生成し、メタデータを適当にエディットし、保存すれば完成です。

Sigil で、ツール→目次→目次を生成 で、目次を生成するときは、レベル以下:3にし、h1 つまりタイトルだけは目次から除外しておきます。そして、Text の nav.xhtml を Section0001.xhtml より上に持っていきます。ツール→Epub3ツール→epub2電子リーダー用のNCX/ガイドの生成 で toc.ncx も生成しておきます。

なお、実際のテキストのエディットは sample.txt ではなく main.txt というものにしていきます。

main.txt だと、上記コマンドは、

```sh
perl txt2epubhtml.pl
```

だけで OK です。ただし、他の本に使うには、書肆情報を Perl スクリプトにベタ書きで指定しているので、Perl の知識も多少必要です。スクリプトの冒頭の変数定義部分だけ変えれば、たいていは使えるはずです。

なお、BOOK☆WALKER など、外部リンクがあると受け取ってもらえない場合は…、

```sh
perl txt2epubhtml.pl sample.txt -o Section0001.xhtml --no-link
```

などとして生成した Section0001.xhtml を使うと良いでしょう。


## gen_sample.pl

main.txt から sample.txt を生成するには、

```sh
perl gen_sample.pl main.txt -o sample.txt
```

…としてください。他の本に使う際は、gen_sample.pl を見れば、冒頭どこをいじれば良いかわかるはずです。


## make_tex.pl

PDF ファイルを作るには、

```sh
perl make_tex.pl sample.txt -c cover_book-sample.png -o sample.tex
lualatex sample.tex
lualatex sample.tex
```

…とします。Amazon POD 用の PDF を作るには、

```sh
perl make_tex.pl sample.txt -c cover_book-sample.png -o sample.tex --amazon
lualatex sample.tex
lualatex sample.tex
```

…とします。デフォルトは main.txt main.tex に対するものというのは、txt2epubhtml.pl と同じです。

スクリプトの冒頭の変数定義部分だけ変えれば、他の本でも、たいていは使えるはずです。


## TXT ファイルの作り方

テキストの表記法は sample.txt をご参照いただくのが一番わかりやすいと思いますがいちおう説明します。

まず、ルビは 漢字\[かんじ\] などとして指定します。少し複雑はルビは \{\{ruby:漢字:ルビ\}\} のように書くこともできます。後ろのほうだけルビを付けたいときは常用\[\]漢字\[かんじ\]といった使い方もできます。

章(chapter) は、

```
X. 新たな章 (略称, 日付)
```

…といった具合に X\. を付けて開始します。略称の部分を付けないと、その章は無視されます。わざと無視される章を作ってメモとして使うと便利です。

節(section) は、

```
  ** セクション
```

サブセクションは、

```
  * サブセクション
```

…というようにはじめます。

章や節は参照ができます。章の参照は \{\{chapter:略称\}\} で行います。節の参照は 《セクション》 のように行います。節の参照には自動的に章の参照が付きます。章の参照を禁じたい場合は 《nc:セクション》 とします。なお セクション が「セクション - サブタイトル」という形式の場合、《セクション》だけでも参照できます。

引用は

```
<quote>
引用〜
</quote>
```

…とします。

ちょっと浮いた文にしたいときは

```
<display>
文
</display>
```

…とします。

ol や ul タグに相当するリストなどは簡易にしか対応していません。

```
<list>
● つらつら

2. つらつら

</list>
```

…などとします。

pre タグにも(簡易的に)対応しています。

```
<b>強調</b>
```

…も使えます。

```
<comment>
文
</comment>
```

…で、文をコメントアウトできます。

タグのネストはできません。

```
{{XXX.png}}
```

…のように .png を指定すると、そこにイメージが表示されます。ただし、EPUB の場合、その .png は epub の Images ディレクトリにないといけません。TeX の場合は、make_tex.pl をいじって、GRAPHICX_OPTION を指定する必要があります。

「 -- 」は、emダッシュ×2「——」に変換されます。

なお、半角数字の表記法がほぼ決まっています。詳述しませんが、警告が表示されるのでそれを参考に直してください。ここも Perl の知識があって、警告をコントロールするのが吉です。

参考文献は、「参考文献」という章を作り、本は…、

```
『参考文献』(著者名, 出版社, 年月日)
https://amazon.〜
https://7net.〜
```

…などと指定します。URL は amazon や 7net ぐらいしか使えないようにわざとしています。他のサイトを足したいときは Perl スクリプトをいじってください。

一般のネットサイトは、

```
《サイト》  
https://〜
```

…というふうに指定します。

参照するとき 《サイト - サブタイトル》 や 『参考文献 - サブタイトル』という形式は、《サイト》または『参考文献』だけでも参照できます。

参照すべきところがない『』や《》に警告を出さないようにするためには、「参照なし」という章を作り改行で羅列していきます。特定の節ですべて警告を無視する場合は「参照なし節」という章に、その節を改行で羅列していきます。


## Author

JRF ( http://jrf.cocolog-nifty.com/statuses , Twitter (X): @jion_rockford )


## License

MIT License.


----
(This document is mainly written in Japanese/UTF8.)
