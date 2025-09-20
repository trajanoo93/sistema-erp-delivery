import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/sidebar_menu.dart';
import 'enums.dart';
import 'pages/dashboard_page.dart';
import 'pages/pedidos_page.dart';
import 'pages/criar_pedido_page.dart';
import 'pages/criar_link_page.dart';
import 'pages/conferir_pagamentos_page.dart';
import 'pages/suporte_page.dart';
import 'pages/unidades_page.dart'; // Placeholder
import 'pages/ranking_page.dart'; // Nova página

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Painel ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MenuItem _selectedMenu = MenuItem.dashboard;
  SubItem? _selectedSubItem;

  void _onMenuItemSelected(MenuItem menuItem, {SubItem? subItem}) {
    setState(() {
      _selectedMenu = menuItem;
      _selectedSubItem = subItem;
    });
  }

  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case MenuItem.dashboard:
        return const DashboardPage();
      case MenuItem.pedidos:
        if (_selectedSubItem == PedidosSubItem.criarPedido) {
          return const CriarPedidoPage();
        } else if (_selectedSubItem == PedidosSubItem.verPedidos) {
          return const PedidosPage();
        }
        return const PedidosPage(); // Default para "Ver Pedidos"
      case MenuItem.pagamentos:
        if (_selectedSubItem == PagamentosSubItem.criarLink) {
          return const CriarLinkPage();
        } else if (_selectedSubItem == PagamentosSubItem.conferirPagamentos) {
          return const ConferirPagamentosPage();
        }
        return const Center(child: Text('Selecione uma opção em Pagamentos'));
      case MenuItem.suporte:
        return const SuportePage();
      case MenuItem.unidades:
        return const UnidadesPage(); // Placeholder
      default:
        return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SidebarMenu(
            selectedMenu: _selectedMenu,
            selectedSubItem: _selectedSubItem,
            onMenuItemSelected: _onMenuItemSelected,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }
}