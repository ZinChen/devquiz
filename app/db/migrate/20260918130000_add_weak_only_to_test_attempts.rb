class AddWeakOnlyToTestAttempts < ActiveRecord::Migration[8.1]
  def change
    # Тренировка по ошибкам: прохождение подмножества вопросов теста. В
    # статистику теста такие попытки не идут, но в личной истории остаются —
    # флаг нужен, чтобы отличить их в кабинете.
    add_column :test_attempts, :weak_only, :boolean, null: false, default: false
  end
end
