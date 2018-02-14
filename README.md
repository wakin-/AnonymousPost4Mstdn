# FediverseStation
アカウントへのメンションの内容を投稿者名と共にトゥートします。アカウントの発言TL上でチャットする感じの使い方です。外インスタンスからフォローすることで、発言TL上に同一のTLが再現されます。特定の話題を募集することで話題の集積場にすることも出来そうです。

## 使い方
1. 以下を参考に`key.yml`という設定ファイルを作成し、どうにかして`base_url`と`access_token`を入手して記載する。
```yml
base_url: theboss.tech
access_token: ******
```
オプションで`post_message`を記載することで発言者を表示する部分を編集できる。`[acct]`が投稿者の`id@domain`に置き換えれられる。
```yml
post_message: "\n [acct] posted"
```
オプションで`hashtag`を記載することでトゥートにハッシュタグを付加することも可能。
```yml
hashtag: fediverse_station
```
オプションで`keep_id_day`を記載すると、記載した日数だけ情報がキープされ、投稿元の削除の反映、ファボ・ブーストを投稿者に通知する機能が有効化される。
```yml
keep_id_day: 7
```

2. `bundle install`
3. `bundle exec ruby main.rb`
4.  ✌('ω'✌ )三✌('ω')✌三( ✌'ω')✌