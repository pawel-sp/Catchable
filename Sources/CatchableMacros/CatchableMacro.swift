import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CatchableMacro {
    enum Error: Swift.Error, CustomStringConvertible {
        case onlyApplicableToProtocol
        case customInitNotAllowed
        case varSettersNotAllowed

        public var description: String {
            switch self {
            case .onlyApplicableToProtocol:
                "@Catchable can only be applied to protocols."
            case .customInitNotAllowed:
                "@Catchable does not support protocols that define custom initializers."
            case .varSettersNotAllowed:
                "@Catchable does not support protocols with variable requirements that include setters."
            }
        }
    }
}

extension CatchableMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw Error.onlyApplicableToProtocol
        }
        guard !protocolDecl.variablesDecl.contains(where: \.setterExists) else {
            throw Error.varSettersNotAllowed
        }
        guard protocolDecl.initializersDecl.isEmpty else {
            throw Error.customInitNotAllowed
        }
        return [.init(classDecl(from: protocolDecl))]
    }

    private static func variablesDecl(from protocolDecl: ProtocolDeclSyntax) -> [VariableDeclSyntax] {
        protocolDecl.variablesDecl.map { varDecl in
            .init(
                attributes: varDecl.attributes,
                bindingSpecifier: varDecl.bindingSpecifier.withoutTrivia(),
                bindings: .init(
                    varDecl.bindings.map(varBindingSyntax(from:))
                )
            )
        } +
        [
            .init(
                modifiers: [DeclModifierSyntax(name: TokenSyntax.keyword(.private))],
                Keyword.let,
                name: .init(stringLiteral: "wrapped"),
                type: .init(type: TypeSyntax(stringLiteral: protocolDecl.name.text))
            ),
            .init(
                modifiers: [DeclModifierSyntax(name: TokenSyntax.keyword(.private))],
                Keyword.let,
                name: .init(stringLiteral: "errorProcessor"),
                type: .init(type: TypeSyntax(stringLiteral: "ErrorProcessor"))
            )
        ]
    }

    private static func varBindingSyntax(from protocolVarBindingDecl: PatternBindingSyntax) -> PatternBindingSyntax {
        .init(
            pattern: protocolVarBindingDecl.pattern,
            typeAnnotation: protocolVarBindingDecl.typeAnnotation,
            accessorBlock: protocolVarBindingDecl.accessorBlock.map { accessorBlock in
                .init(
                    accessors: .accessors(.init([
                        accessorBlock.accessors.getterDecl.map { getterDecl in
                            AccessorDeclSyntax(
                                accessorSpecifier: getterDecl.accessorSpecifier,
                                effectSpecifiers: getterDecl.effectSpecifiers,
                                body: CodeBlockSyntax(
                                    statements: CodeBlockItemListSyntax {
                                        if getterDecl.effectSpecifiers?.asyncSpecifier != nil {
                                            AwaitExprSyntax(
                                                expression: ExprSyntax("wrapped.\(protocolVarBindingDecl.pattern)")
                                            )
                                        } else {
                                            ExprSyntax("wrapped.\(protocolVarBindingDecl.pattern)")
                                        }
                                    }
                                )
                            )
                        }
                    ].compactMap { $0 }))
                )
            }
        )
    }

    private static func functionsDecl(from protocolDecl: ProtocolDeclSyntax) -> [FunctionDeclSyntax] {
        protocolDecl.functionsDecl.map { funcDecl in
            .init(
                attributes: AttributeListSyntax.init(
                    funcDecl.attributes
                        .compactMap { $0.as(AttributeSyntax.self) }
                        .map { .init(AttributeSyntax(attributeName: $0.attributeName)) }
                ),
                name: funcDecl.name,
                signature: funcDecl.signature,
                body: .init {
                    if funcDecl.signature.effectSpecifiers?.throwsClause != nil {
                        DoStmtSyntax(
                            catchClauses: .init([
                                .init(
                                    body: .init {
                                        callErrorProcessorSyntax()
                                    }
                                )
                            ]),
                            bodyBuilder: {
                                if
                                    funcDecl.signature.returnClause != nil &&
                                    funcDecl.signature.returnClause?.type.as(
                                        IdentifierTypeSyntax.self
                                    )?.name.text != "Void"
                                {
                                    ReturnStmtSyntax(expression: callWrappedFuncDecl(from: funcDecl))
                                } else {
                                    callWrappedFuncDecl(from: funcDecl)
                                }
                            }
                        )
                    } else {
                        callWrappedFuncDecl(from: funcDecl)
                    }
                }
            )
        }
    }

    private static func callErrorProcessorSyntax() -> ThrowStmtSyntax {
        .init(
            expression: FunctionCallExprSyntax(
                calledExpression: ExprSyntax("errorProcessor"),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    LabeledExprSyntax(expression: ExprSyntax(stringLiteral: "error"))
                },
                rightParen: .rightParenToken()
            )
        )
    }

    private static func callWrappedFuncDecl(from protocolFuncDecl: FunctionDeclSyntax) -> ExprSyntaxProtocol {
        let parameters = protocolFuncDecl.signature.parameterClause.parameters
        let effectSpecifiers = protocolFuncDecl.signature.effectSpecifiers
        let funcCallExpr = FunctionCallExprSyntax(
            calledExpression: ExprSyntax("wrapped.\(protocolFuncDecl.name)"),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(
                parameters.enumerated().map { index, parameter in
                    LabeledExprSyntax(
                        label: parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.withoutTrivia(),
                        colon: parameter.firstName.tokenKind == .wildcard ? nil : .colonToken(),
                        expression: ExprSyntax(
                            stringLiteral: parameter.secondName?.text ?? parameter.firstName.text
                        ),
                        trailingComma: index == parameters.count - 1 ? nil : .commaToken()
                    )
                }
            ),
            rightParen: .rightParenToken()
        )
        if effectSpecifiers?.throwsClause != nil && effectSpecifiers?.asyncSpecifier != nil {
            return TryExprSyntax(expression: AwaitExprSyntax(expression: funcCallExpr))
        } else if effectSpecifiers?.throwsClause != nil {
            return TryExprSyntax(expression: funcCallExpr)
        } else if effectSpecifiers?.asyncSpecifier != nil {
            return AwaitExprSyntax(expression: funcCallExpr)
        } else {
            return funcCallExpr
        }
    }

    private static func initDecl(from protocolDecl: ProtocolDeclSyntax) -> InitializerDeclSyntax {
        .init(
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            firstName: TokenSyntax.wildcardToken(),
                            secondName: TokenSyntax(stringLiteral: "wrapped"),
                            type: TypeSyntax(stringLiteral: protocolDecl.name.text),
                            trailingComma: .commaToken()
                        ),
                        FunctionParameterSyntax(
                            firstName: TokenSyntax(stringLiteral: "errorProcessor"),
                            type: TypeSyntax(stringLiteral: "ErrorProcessor")
                        )
                    ])
                )
            ),
            body: .init {
                ExprSyntax("self.wrapped = wrapped")
                ExprSyntax("self.errorProcessor = errorProcessor")
            }
        )
    }

    private static func classDecl(from protocolDecl: ProtocolDeclSyntax) -> ClassDeclSyntax {
        .init(
            modifiers: [
                DeclModifierSyntax(name: TokenSyntax.keyword(.private)),
                DeclModifierSyntax(name: TokenSyntax.keyword(.final))
            ],
            name: TokenSyntax(stringLiteral: "CatchableDecorator"),
            inheritanceClause: InheritanceClauseSyntax(inheritedTypes: .init([
                .init(type: TypeSyntax(stringLiteral: protocolDecl.name.text))
            ])),
            memberBlock: MemberBlockSyntax(
                members: .init(
                    variablesDecl(from: protocolDecl).map { MemberBlockItemSyntax(decl: $0) } +
                    [MemberBlockItemSyntax(decl: initDecl(from: protocolDecl))] +
                    functionsDecl(from: protocolDecl).map { MemberBlockItemSyntax(decl: $0) }
                )
            )
        )
    }
}

extension CatchableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            throw Error.onlyApplicableToProtocol
        }
        return [extensionDecl(from: protocolDecl)]
    }

    private static func extensionDecl(from protocolDecl: ProtocolDeclSyntax) -> ExtensionDeclSyntax {
        .init(
            extendedType: TypeSyntax(stringLiteral: protocolDecl.name.text),
            memberBlock: .init(
                members: .init([
                    .init(
                        decl: FunctionDeclSyntax(
                            modifiers: protocolDecl.accessModifiers,
                            name: TokenSyntax(stringLiteral: "catchable"),
                            signature: .init(
                                parameterClause: .init(
                                    parameters: .init {
                                        FunctionParameterSyntax(
                                            firstName: TokenSyntax(stringLiteral: "errorProcessor"),
                                            type: TypeSyntax(stringLiteral: "ErrorProcessor")
                                        )
                                    }
                                ),
                                returnClause: .init(type: TypeSyntax(stringLiteral: protocolDecl.name.text))
                            ),
                            body: .init(
                                statements: .init {
                                    FunctionCallExprSyntax(
                                        calledExpression: ExprSyntax("CatchableDecorator"),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax {
                                            LabeledExprSyntax(
                                                expression: ExprSyntax(stringLiteral: "self")
                                            )
                                            LabeledExprSyntax(
                                                label: "errorProcessor",
                                                expression: ExprSyntax(stringLiteral: "errorProcessor")
                                            )
                                        },
                                        rightParen: .rightParenToken()
                                    )
                                }
                            )
                        )
                    )
                ])
            )
        )
    }
}

private extension ProtocolDeclSyntax {
    var accessModifiers: DeclModifierListSyntax {
        modifiers.filter {
            $0.name.text == TokenSyntax.keyword(.public).text ||
            $0.name.text == TokenSyntax.keyword(.internal).text ||
            $0.name.text == TokenSyntax.keyword(.private).text ||
            $0.name.text == TokenSyntax.keyword(.fileprivate).text
        }
    }

    var variablesDecl: [VariableDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
    }

    var initializersDecl: [InitializerDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
    }

    var functionsDecl: [FunctionDeclSyntax] {
        memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self) }
    }
}

private extension VariableDeclSyntax {
    var setterExists: Bool {
        bindings.contains(where: { $0.accessorBlock?.accessors.setterDecl != nil })
    }
}

private extension AccessorBlockSyntax.Accessors {
    var getterDecl: AccessorDeclSyntax? {
        self.as(AccessorDeclListSyntax.self)?.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) })
    }

    var setterDecl: AccessorDeclSyntax? {
        self.as(AccessorDeclListSyntax.self)?.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.set) })
    }
}

private extension TokenSyntax {
    func withoutTrivia() -> TokenSyntax {
        .init(
            tokenKind,
            leadingTrivia: [],
            trailingTrivia: [],
            presence: presence
        )
    }
}
