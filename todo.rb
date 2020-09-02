#! /usr/bin/env ruby

require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

require 'pry' if development?
#### README #####
# Data structure is array of hashes.
# Each hash is a single list
# In a list, hash[:todos] contains an array of todo hashes
# Each todo hash contains the attributes of the todo item
################

configure do
  set :sessions,
    session_secret: 'secret',
    expire_after: 365*24*60*60 # 365 days in seconds
end

before do
  session[:lists] ||= []
end


helpers do
  def class_complete?(list_index)
    todos_array = session[:lists][list_index.to_i][:todos]

    if !todos_array.empty? && todos_array.all? { |todo_hash| todo_hash[:completed] }
      "complete"
    end
  end

  def count_incomplete(list_index)
    todos_array = session[:lists][list_index.to_i][:todos]

    todos_array.count { |todo_hash| !todo_hash[:completed] }
  end

  def count_total_todos(list_index)
    session[:lists][list_index.to_i][:todos].size
  end

  def sorted_todos(list_index)
    todos_array = session[:lists][list_index.to_i][:todos]

    todos_array
    .map
    .with_index { |hash, index| [hash, index] }
    .sort do |sub_array1, sub_array2|
      sub_array1.first[:completed].to_s <=> sub_array2.first[:completed].to_s
    end
    .each { |(todo, index)| yield(todo, index) }
  end

  def sorted_lists(lists_array)
    lists_array
      .map
      .with_index { |hash, index| [hash, index] }
      .sort do |sub_array1, sub_array2|
        (class_complete?(sub_array1.last) || '') <=> (class_complete?(sub_array2.last) || '')
      end
      .each { |(list, index)| yield(list, index) }
  end
end

get '/' do
  redirect '/lists'
end

# View all the lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render HTML form to create a new list
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Retrieves a particular todo list hash
get "/lists/:id" do |index|
  @list_index = index.to_i
  begin
    @list = session[:lists].fetch(@list_index)
  rescue
    redirect "/"
  end

  @list_name, @todos = @list[:name], @list[:todos]

  erb :list, layout: :layout
end

# Render HTML form to edit list name
get "/lists/:id/edit" do |id|
  @index = id
  @list = session[:lists].fetch(@index.to_i)
  @list_name = @list[:name]
  erb :edit_list, layout: :layout  
end

# Update existing list
post "/lists/:id" do |index|
  @index = index
  @list_name = params[:list_name].strip
  current_list_name = session[:lists][index.to_i][:name]

  if params[:list_name] == current_list_name
    redirect "/lists/#{index}"
  elsif session[:error] = error_for_list_name(@list_name)
    erb :edit_list, layout: :layout
  else
    session[:lists][index.to_i][:name] = @list_name 
    session[:success] = 'The list was edited successfully.'
    redirect "/lists/#{index}"
  end
end

# Returns error message for invalid or non-unique name. Nil otherwise.
def error_for_list_name(list_name)
  if !list_name.size.between?(1, 100)
    'Between 1 and 100 characters'
  elsif session[:lists].any? { |list| list[:name] == list_name }
    'Must be unique name.'
  end
end

# Returns error message if todo is blank. Nil otherwise.
def error_for_todo(text)
  if !text.size.between?(1, 100)
    'Between 1 and 100 characters'
  end
end


# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
 
  if (session[:error] = error_for_list_name(list_name))
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list \"#{list_name}\" was added successfully."
    redirect '/lists'
  end
end

# Delete a list
post "/lists/:id/destroy" do |index|
  list_name = session[:lists][index.to_i][:name]
  session[:lists].delete_at(index.to_i)
  session[:success] = "The list \"#{list_name}\" has been deleted."
  redirect "/lists"
end

# Add a todo to the list
post "/lists/:list_id/todos" do |index|
  @list_index = index.to_i
  @text = params[:todo].strip

  if (session[:error] = error_for_todo(@text))
    erb :list, layout: :layout
  
  else
    todos_array = session[:lists][@list_index][:todos]
    todos_array << { name: @text, completed: false }

    session[:success] = "\"#{@text}\" added to the list."
    redirect "/lists/#{index}"
  end
end

# Delete todo item from list
post "/lists/:list_id/todos/:todo_id/destroy" do |list_id, todo_id|
  @list_index = list_id.to_i
  @todo_index = todo_id.to_i

  todos_array = session[:lists][@list_index][:todos]
  todo = todos_array.delete_at(@todo_index)

  session[:success] = "The todo \"#{todo[:name]}\" has been deleted"
  redirect "/lists/#{@list_index}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:todo_id" do |list_id, todo_id|
  @list_index = list_id.to_i
  @todo_index = todo_id.to_i

  todo_hash = session[:lists][@list_index][:todos][@todo_index]

  is_completed = params[:completed] == 'true'
  todo_hash[:completed] = is_completed

  session[:success] = "The todo \"#{todo_hash[:name]}\" has been marked #{is_completed ? "" : "not"} complete."

  redirect "/lists/#{@list_index}"
end

post "/lists/:list_id/complete" do |index|
  @list_id = index.to_i
  todo_array = session[:lists][@list_id][:todos]

  todo_array.each { |todo_hash| todo_hash[:completed] = true }

  session[:success] = "All todos completed!"
  redirect "/lists/#{@list_id}"
end

# not_found do
#   redirect "/"
# end
