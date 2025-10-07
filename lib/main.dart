import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart';
import 'widgets/sidebar_menu.dart';
import 'enums.dart';
import 'pages/dashboard_page.dart';
import 'pages/pedidos_page.dart';
import 'pages/criar_pedido_page.dart';
import 'pages/criar_link_page.dart';
import 'pages/conferir_pagamentos_page.dart';
import 'pages/suporte_page.dart';
import 'pages/unidades_page.dart';
import 'pages/feedback.dart';
import 'pages/auth_page.dart';
import 'provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Meu Painel ERP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: Colors.white,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('pt', 'BR'),
        ],


        home: const AuthWrapper(),
      ),
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<bool> _checkLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    if (id != null) {
      final name = users[id];
      if (name != null) {
        Provider.of<AuthProvider>(context, listen: false).setUser(id, name);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) {
          return const HomePage();
        } else {
          return const AuthPage();
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
        return const PedidosPage();
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
        return const UnidadesPage();
      case MenuItem.feedback:
        return const FeedbackPage();
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