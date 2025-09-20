// lib/enums.dart

// Interface para subitens
abstract class SubItem {}

// Enum para subitens de Pedidos
enum PedidosSubItem implements SubItem {
  criarPedido,
  verPedidos,
}

// Enum para subitens de Pagamentos
enum PagamentosSubItem implements SubItem {
  criarLink,
  conferirPagamentos,
}

// Enum para itens principais do menu
enum MenuItem {
  dashboard,
  pedidos,
  pagamentos,
  suporte,
  unidades,
  
}