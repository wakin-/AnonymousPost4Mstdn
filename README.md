# FediverseStation
アカウントへのメンションの内容を投稿者名と共にトゥートします。アカウントの発言TL上でチャットする感じの使い方です。外インスタンスからフォローすることで、発言TL上に同一のTLが再現されます。特定の話題を募集することで話題の集積場にすることも出来そうです。

## 使い方
1. 以下を参考に`key.yml`という設定ファイルを作成し、どうにかして`base_url`と`access_token`を入手して記載する。`account`には名前を入れてください。
```key.yml
base_url: theboss.tech
access_token: ******
account: echo
```
オプションでhashtagを記載することでトゥートにハッシュタグを付加することも可能。
```
hashtag: fediverse_station
```
2. `bundle install`
3. `bundle exec ruby main.rb`
4.  ✌('ω'✌ )三✌('ω')✌三( ✌'ω')✌