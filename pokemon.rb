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

# Executando o programa
app = App.new
app.executar
app.listar
app.close
