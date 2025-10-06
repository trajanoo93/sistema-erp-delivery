import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'criar_pedido_service.dart';

class ProductSelectionDialog extends StatefulWidget {
  const ProductSelectionDialog({super.key});

  @override
  State<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.length >= 3) {
      _fetchProducts(query);
    } else {
      setState(() {
        _products = [];
      });
    }
  }

  Future<void> _fetchProducts(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await CriarPedidoService().fetchProducts(query);
      setState(() {
        _products = products;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar produtos: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _showVariationDialog(Map<String, dynamic> product) async {
    final attributes = await CriarPedidoService().fetchProductAttributes(product['id']);
    final variations = await CriarPedidoService().fetchProductVariations(product['id']);

    Map<String, String> selectedAttributes = {};
    for (var attr in attributes) {
      selectedAttributes[attr['name']] = attr['options'].first;
    }

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Monta a lista de variações disponíveis com base nos atributos selecionados
            List<Map<String, dynamic>> availableVariations = variations.where((variation) {
              bool isMatch = true;
              for (var attr in variation['attributes']) {
                final attrName = attr['name'];
                final attrOption = attr['option'];
                if (selectedAttributes[attrName] != attrOption) {
                  isMatch = false;
                  break;
                }
              }
              return isMatch;
            }).toList();

            return AlertDialog(
              title: Text(
                'Selecione as Variações',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...attributes.map((attr) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          value: selectedAttributes[attr['name']],
                          decoration: InputDecoration(
                            labelText: attr['name'],
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: (attr['options'] as List<dynamic>).map((option) {
                            return DropdownMenuItem<String>(
                              value: option.toString(),
                              child: Text(option.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedAttributes[attr['name']] = value!;
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    if (availableVariations.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Variação Selecionada:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...availableVariations.map((variation) {
                            final isInStock = variation['stock_status'] == 'instock';
                            return Opacity(
                              opacity: isInStock ? 1.0 : 0.5,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'R\$ ${variation['price'].toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          isInStock ? Icons.check_circle : Icons.cancel,
                                          color: isInStock ? Colors.green : Colors.red,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isInStock ? 'Em Estoque' : 'Fora de Estoque',
                                          style: GoogleFonts.poppins(
                                            color: isInStock ? Colors.green : Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      )
                    else
                      Text(
                        'Nenhuma variação disponível para os atributos selecionados.',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Encontrar a variação correspondente aos atributos selecionados
                    Map<String, dynamic>? selectedVariation;
                    for (var variation in variations) {
                      bool isMatch = true;
                      for (var attr in variation['attributes']) {
                        final attrName = attr['name'];
                        final attrOption = attr['option'];
                        if (selectedAttributes[attrName] != attrOption) {
                          isMatch = false;
                          break;
                        }
                      }
                      if (isMatch) {
                        selectedVariation = variation;
                        break;
                      }
                    }

                    if (selectedVariation != null) {
                      final isInStock = selectedVariation['stock_status'] == 'instock';
                      if (!isInStock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Esta variação está fora de estoque e não pode ser adicionada.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final variationAttributes = selectedAttributes.entries.map((entry) {
                        return {
                          'name': entry.key,
                          'option': entry.value,
                        };
                      }).toList();
                      print('Variation selected: $selectedVariation');
                      print('Variation attributes construídas: $variationAttributes');
                      Navigator.of(context).pop({
                        'id': selectedVariation['id'],
                        'attributes': variationAttributes,
                        'price': selectedVariation['price'],
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhuma variação correspondente encontrada')),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirmar',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectProduct(Map<String, dynamic> product) async {
    // Verifica se o produto está em estoque
    final isInStock = product['stock_status'] == 'instock';
    if (!isInStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este produto está fora de estoque e não pode ser adicionado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (product['type'] == 'variable') {
      final variation = await _showVariationDialog(product);
      if (variation != null) {
        print('Returning variable product: ${{
          'id': product['id'],
          'name': product['name'],
          'price': variation['price'],
          'variation_id': variation['id'],
          'variation_attributes': variation['attributes'],
          'image': product['image'],
        }}');
        Navigator.of(context).pop({
          'id': product['id'],
          'name': product['name'],
          'price': variation['price'],
          'variation_id': variation['id'],
          'variation_attributes': variation['attributes'],
          'image': product['image'],
        });
      }
    } else {
      print('Returning simple product: ${{
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'variation_id': null,
        'variation_attributes': null,
        'image': product['image'],
      }}');
      Navigator.of(context).pop({
        'id': product['id'],
        'name': product['name'],
        'price': product['price'],
        'variation_id': null,
        'variation_attributes': null,
        'image': product['image'],
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Selecionar Produto',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar Produto (mín. 3 caracteres)',
                labelStyle: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.orange.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.orange.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.orange.shade600,
                    width: 2,
                  ),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.orange.shade600,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_products.isEmpty && _searchController.text.length >= 3)
              Text(
                'Nenhum produto encontrado',
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isInStock = product['stock_status'] == 'instock';

                    return Opacity(
                      opacity: isInStock ? 1.0 : 0.5,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: product['image'] != null
                              ? Image.network(
                                  product['image'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(
                            product['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'R\$ ${product['price'].toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    isInStock ? Icons.check_circle : Icons.cancel,
                                    color: isInStock ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isInStock ? 'Em Estoque' : 'Fora de Estoque',
                                    style: GoogleFonts.poppins(
                                      color: isInStock ? Colors.green : Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: isInStock ? () => _selectProduct(product) : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.poppins(
              color: Colors.red.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}