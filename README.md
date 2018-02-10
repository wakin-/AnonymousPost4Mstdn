# FediverseStation
アカウントへのメンションの内容を投稿者名と共にトゥートします。アカウントの発言TL上でチャットする感じの使い方です。外インスタンスからフォローすることで、発言TL上に同一のTLが再現されます。特定の話題を募集することで話題の集積場にすることも出来そうです。

## 使い方
1. 以下を参考に`key.yml`という設定ファイルを作成し、どうにかして`base_url`と`access_token`を入手して記載する。`account`には名前を入れてください。
```key.yml
base_url: theboss.tech
access_token: tx8j4j3yb5ibxuns6i3w73ndpffmg4c7jxcr7jr5psgn5de4a38k5d5jjc4tsir8
account: AnonymousPost
```
3. `bundle install`
4. `bundle exec ruby main.rb`
5.  ✌('ω'✌ )三✌('ω')✌三( ✌'ω')✌