# Consumo de API Pokémon com Ruby e PostgreSQL

**Disciplina:** Programação Avançada  
**Professor:** José Anchieta  
**Aluno:** Yuri Alves Moreira  
**Curso:** Sistemas de Informação – VI Período, Noturno  

---

## Descrição do Projeto

Este projeto tem como objetivo **praticar o consumo de APIs REST usando Ruby**, persistir os dados no **PostgreSQL** e permitir a consulta dos registros armazenados.  
A aplicação consome a **API pública de Pokémon** ([PokéAPI](https://pokeapi.co/)) e armazena informações como: ID, nome, URL, altura, peso e tipos dos Pokémons
a PokéAPI é uma API que fornece informações detalhadas sobre todos os Pokémons do universo da franquia.


---

## Objetivos da Atividade

- Praticar o consumo de APIs REST utilizando Ruby.  
- Armazenar dados no banco de dados PostgreSQL.  
- Permitir a consulta dos dados de forma organizada.  
- Trabalhar com orientação a objetos.

---

## Estrutura do Banco de Dados

**Banco:** `pokemon`  
**Tabela:** `pokemons`  

```sql
DROP TABLE IF EXISTS pokemons;

CREATE TABLE pokemons (
    id SERIAL PRIMARY KEY,
    api_id INT UNIQUE,
    name TEXT UNIQUE,
    url TEXT,
    height INT,
    weight INT,
    types TEXT
);

GRANT ALL PRIVILEGES ON TABLE pokemons TO usuario1;
GRANT ALL PRIVILEGES ON SEQUENCE pokemons_id_seq TO usuario1;
```

- `id` → ID interno do PostgreSQL  
- `api_id` → ID do Pokémon na API  
- `name` → Nome do Pokémon  
- `url` → URL do recurso na API  
- `height` → Altura do Pokémon  
- `weight` → Peso do Pokémon  
- `types` → Tipos (Grass, Poison, Fire, etc.)

---

## Descrição da API

**API:** [PokéAPI](https://pokeapi.co/)  
**Recurso Consumido:** `/pokemon`  

- Endpoint utilizado: `https://pokeapi.co/api/v2/pokemon?limit=10`  
- Campos armazenados: `id`, `name`, `url`, `height`, `weight`, `types`  
- Observação: A API permite consumir todos os Pokémons com paginação, mas o projeto inicial consome apenas os 10 primeiros para fins de demonstração.

---

## Código Ruby (`pokemon.rb`)

O código está organizado em três classes principais:  

- `Database` → gerencia a conexão com PostgreSQL, criação de tabela, inserção e listagem.  
- `PokemonAPI` → consome a API pública de Pokémons e formata os dados.  
- `App` → coordena a execução da aplicação, chamando a API e inserindo no banco, além de exibir os dados.

```ruby
require 'pg'
require 'httparty'
require 'json'
require 'colorize'

class Database
  def initialize
    @conn = PG.connect(
      dbname: 'pokemon',
      user: 'usuario1',
      password: 'senha1',
      host: 'localhost',
      port: 5432
    )
  end

  def criar_tabela
    @conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS pokemons (
        id SERIAL PRIMARY KEY,
        api_id INT UNIQUE,
        name TEXT UNIQUE,
        url TEXT,
        height INT,
        weight INT,
        types TEXT
      );
    SQL
  end

  def inserir_pokemon(api_id, name, url, height, weight, types)
    @conn.exec_params(
      "INSERT INTO pokemons (api_id, name, url, height, weight, types)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (api_id) DO NOTHING;",
      [api_id, name, url, height, weight, types]
    )
  end

  def listar_pokemons
    result = @conn.exec("SELECT * FROM pokemons ORDER BY api_id;")
    puts "-" * 70
    puts "| %-3s | %-12s | %-6s | %-6s | %-20s |" % ["ID", "Nome", "Altura", "Peso", "Tipos"]
    puts "-" * 70
    result.each do |row|
      puts "| %-3s | %-12s | %-6s | %-6s | %-20s |" % [
        row['api_id'].to_s.colorize(:cyan),
        row['name'].capitalize.colorize(:light_green),
        row['height'].to_s.colorize(:yellow),
        row['weight'].to_s.colorize(:yellow),
        row['types'].capitalize.colorize(:light_blue)
      ]
    end
    puts "-" * 70
  end

  def close
    @conn.close if @conn
  end
end

class PokemonAPI
  BASE_URL = "https://pokeapi.co/api/v2/pokemon?limit=10"

  def self.get_pokemons
    response = HTTParty.get(BASE_URL)
    return [] unless response.code == 200

    pokemons = []
    response.parsed_response['results'].each do |p|
      detail = HTTParty.get(p['url'])
      if detail.code == 200
        data = detail.parsed_response
        types = data['types'].map { |t| t['type']['name'] }.join(', ')
        pokemons << {
          api_id: data['id'],
          name: data['name'],
          url: p['url'],
          height: data['height'],
          weight: data['weight'],
          types: types
        }
      end
    end
    pokemons
  end
end

class App
  def initialize
    @db = Database.new
    @db.criar_tabela
  end

  def executar
    pokemons = PokemonAPI.get_pokemons
    pokemons.each do |p|
      @db.inserir_pokemon(p[:api_id], p[:name], p[:url], p[:height], p[:weight], p[:types])
    end
    puts "Pokémons inseridos com sucesso!".colorize(:green)
  end

  def listar
    puts "Lista de Pokémons armazenados:".colorize(:blue).bold
    @db.listar_pokemons
  end

  def close
    @db.close
  end
end

app = App.new
app.executar
app.listar
app.close
```

---

## Como Rodar a Aplicação

1. Instale as gems necessárias:

```bash
gem install pg
gem install httparty
gem install colorize
```

2. Abra o terminal na pasta do projeto.  
3. Execute o script Ruby:

```bash
ruby pokemon.rb
```

- Ele criará a tabela, buscará os 10 primeiros Pokémons da API, inserirá no banco e exibirá os registros em uma tabela colorida no terminal.

---

## Resultados Esperados

```
Pokémons inseridos com sucesso!
Lista de Pokémons armazenados:
---------------------------------------------------------------------
| ID  | Nome         | Altura | Peso   | Tipos               |
---------------------------------------------------------------------
| 1   | Bulbasaur    | 7      | 69     | Grass, Poison       |
| 2   | Ivysaur      | 10     | 130    | Grass, Poison       |
| 3   | Venusaur     | 20     | 1000   | Grass, Poison       |
| 4   | Charmander   | 6      | 85     | Fire                |
| 5   | Charmeleon   | 11     | 190    | Fire                |
| 6   | Charizard    | 17     | 905    | Fire, Flying        |
| 7   | Squirtle     | 5      | 90     | Water               |
| 8   | Wartortle    | 10     | 225    | Water               |
| 9   | Blastoise    | 16     | 855    | Water               |
| 10  | Caterpie     | 3      | 29     | Bug                 |
```

---

**Fim do README**

